// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin ERC20 & access control
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces for integration with your CreditUnitRegistry
import {CreditUnitRegistry} from "../registry/CreditUnitRegistry.sol";
import {ICarbonCreditToken} from "../interfaces/ICarbonCreditToken.sol";

/// @title CarbonCreditToken
/// @notice Tokenized representation of verified carbon credits.
/// @dev Mints/burns tokens based on retired credits in CreditUnitRegistry.
contract CarbonCreditToken is ERC20, Ownable, ICarbonCreditToken {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    event CarbonCreditMinted(address indexed to, uint256 amount);
    event CarbonCreditRetired(address indexed from, uint256 amount);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------
    error UnauthorizedMinter(address minter);
    error InvalidRegistry(address registry);

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------
    modifier onlyAuthorizedMinter() {
        if (!registry.authorizedMinters(msg.sender)) {
            revert UnauthorizedMinter(msg.sender);
        }
        _;
    }

    /// @notice Reference to the CreditUnitRegistry contract
    CreditUnitRegistry public registry;

    /// @param _registry Address of the CreditUnitRegistry contract
    constructor(
        address _registry
    ) ERC20("Carbon Credit Token", "CCT") Ownable(msg.sender) {
        if (_registry == address(0)) revert InvalidRegistry(_registry);
        registry = CreditUnitRegistry(_registry);
    }

    // -----------------------------------------------------------------------
    // Minting & Burning (to be expanded with proper access checks)
    // -----------------------------------------------------------------------

    /// @notice Mint carbon credit tokens (only authorized minters via registry)
    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        // TODO: check registry.authorizedMinters(msg.sender)
        _mint(to, amount);
        emit CarbonCreditMinted(to, amount);
    }

    /// @notice Burn carbon credit tokens when credits are retired
    function burnForRetirement(address from, uint256 amount) external {
        if (msg.sender != from && !registry.authorizedMinters(msg.sender)) {
            revert UnauthorizedMinter(msg.sender);
        }
        
        // TODO: hook into registry.retiredCredits
        registry.retiredCredits(from, amount);
        _burn(from, amount);
        emit CarbonCreditRetired(from, amount);
    }
}
