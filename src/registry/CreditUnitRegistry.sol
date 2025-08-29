// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title CreditUnitRegistry (Lite) - Sepolia testnet friendly
/// @notice Minimal registry for simulated carbon credits (add + retire).
/// @dev Designed to be used by a Carbon721 contract.
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CreditUnitRegistry is Ownable {
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    event EntityRegistered(address indexed entity);
    event CreditAdded(address indexed entity, uint256 amount);
    event CreditDeducted(address indexed entity, uint256 amount);
    event AuthorizedMinterSet(address indexed minter, bool allowed);

    event CreditsMinted(
        address indexed entity,
        address indexed by,
        uint256 amount,
        uint256 cumulative
    );

    event CreditsRetired(
        address indexed entity,
        address indexed by,
        uint256 amount,
        uint256 cumulative
    );

    // -----------------------------------------------------------------------
    // Structs & Storage
    // -----------------------------------------------------------------------
    struct CreditUnit {
        string projectId; // Human/registry id
        uint256 vintage; // e.g., "2022"
        string methodology; // e.g., "VCS-XXX"
        string verifier; // e.g., "Verra", "Gold Standard"
        uint256 totalMinted; // Cumulative tokens minted
        uint256 totalRetired; // Cumulative tokens retired
        string metaCid; // Optional IPFS CID for docs
    }

    // One entity -> one credit record (v1)
    mapping(address => CreditUnit) private credits;
    mapping(address => bool) public registered;

    // Authorized external contracts (e.g., Carbon721) allowed to call retire
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedCallers;

    // -----------------------------------------------------------------------
    // Custom Errors
    // -----------------------------------------------------------------------
    error InvalidEntity(address entity);
    error AlreadyRegistered(address entity);
    error EmptyField(string fieldName);
    error InvalidAmount(uint256 amount);
    error InsufficientCredits(uint256 available, uint256 requested);
    error UnauthorizedMinter(address minter);
    error NotAuthorized(address caller);
    error UnregisteredEntity(address entity);
    error UnauthorizedCaller(address entity);

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------
    modifier authorizedMinter() {
        if (!(authorizedMinters[msg.sender] || msg.sender == owner())) {
            revert NotAuthorized(msg.sender);
        }
        _;
    }

    modifier onlyAuthorizedContract() {
        if (!authorizedCallers[msg.sender]) {
            revert UnauthorizedCaller(msg.sender);
        }
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    constructor(address initialOwner) Ownable(initialOwner) {}

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------
    function registerEntity(
        address entity,
        string memory projectId,
        uint256 vintage,
        string memory methodology,
        string memory verifier,
        string memory metaCid
    ) external onlyOwner {
        if (entity == address(0)) revert InvalidEntity(entity);
        if (registered[entity]) revert AlreadyRegistered(entity);
        if (bytes(projectId).length == 0) revert EmptyField("projectId");
        if (bytes(methodology).length == 0) revert EmptyField("methodology");
        if (bytes(verifier).length == 0) revert EmptyField("verifier");

        credits[entity] = CreditUnit({
            projectId: projectId,
            vintage: vintage,
            methodology: methodology,
            verifier: verifier,
            totalMinted: 0,
            totalRetired: 0,
            metaCid: metaCid
        });

        registered[entity] = true;
        emit EntityRegistered(entity);
    }

    function addEntity(address entity) external onlyOwner {
        if (entity == address(0)) revert InvalidEntity(entity);
        if (registered[entity]) revert AlreadyRegistered(entity);

        registered[entity] = true;
        emit EntityRegistered(entity);
    }

    function authorizedMintersAdd(
        address minter,
        bool allowed
    ) external onlyOwner {
        if (minter == address(0)) revert InvalidEntity(minter);
        authorizedMinters[minter] = allowed;

        emit AuthorizedMinterSet(minter, allowed);
    }

    // -----------------------------------------------------------------------
    // Credit Minting
    // -----------------------------------------------------------------------
    function addCredit(
        address entity,
        uint256 amount
    ) external authorizedMinter {
        _recordMint(entity, amount);
    }

    function recordMint(
        address entity,
        uint256 amount
    ) external authorizedMinter {
        _recordMint(entity, amount);
    }

    function _recordMint(address entity, uint256 amount) internal {
        if (entity == address(0)) revert InvalidEntity(entity);
        if (!registered[entity]) revert UnregisteredEntity(entity);
        if (amount == 0) revert InvalidAmount(amount);

        credits[entity].totalMinted += amount;

        emit CreditsMinted(
            entity,
            msg.sender,
            amount,
            credits[entity].totalMinted
        );
    }

    // -----------------------------------------------------------------------
    // Credit Deduction (Admin-only)
    // -----------------------------------------------------------------------
    function deductCredit(address entity, uint256 amount) external onlyOwner {
        _retire(entity, amount);
        emit CreditDeducted(entity, amount);
    }

    // -----------------------------------------------------------------------
    // Retirement Functions
    // -----------------------------------------------------------------------
    function retiredCredits(
        address entity,
        uint256 amount
    ) external authorizedMinter {
        _recordRetire(entity, amount);
    }

    function recordRetire(
        address entity,
        uint256 amount
    ) external authorizedMinter {
        _recordRetire(entity, amount);
    }

    function _retire(address entity, uint256 amount) internal {
        if (entity == address(0)) revert InvalidEntity(entity);
        if (!registered[entity]) revert UnregisteredEntity(entity);
        if (amount == 0) revert InvalidAmount(amount);

        uint256 available = credits[entity].totalMinted -
            credits[entity].totalRetired;
        if (available < amount) revert InsufficientCredits(available, amount);

        credits[entity].totalRetired += amount;
    }

    function _recordRetire(address entity, uint256 amount) internal {
        if (entity == address(0)) revert InvalidEntity(entity);
        if (!registered[entity]) revert UnregisteredEntity(entity);
        if (amount == 0) revert InvalidAmount(amount);

        uint256 available = credits[entity].totalMinted -
            credits[entity].totalRetired;
        if (available < amount) revert InsufficientCredits(available, amount);

        credits[entity].totalRetired += amount;

        emit CreditsRetired(
            entity,
            msg.sender,
            amount,
            credits[entity].totalRetired
        );
    }

    // -----------------------------------------------------------------------
    // View / Getters
    // -----------------------------------------------------------------------
    function getCredit(
        address entity
    ) external view returns (CreditUnit memory) {
        return credits[entity];
    }

    function availableCredits(address entity) external view returns (uint256) {
        if (!registered[entity]) revert UnregisteredEntity(entity);
        return credits[entity].totalMinted - credits[entity].totalRetired;
    }
}
