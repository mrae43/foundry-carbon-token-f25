// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {CreditUnitRegistry} from "../../src/registry/CreditUnitRegistry.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CreditUnitRegistryTest is Test {
    CreditUnitRegistry registry;
    HelperConfig.NetworkConfig config;

    address entity1 = makeAddr("USER"); // the entity we’ll register
    address attacker = makeAddr("ATTACKER"); // an unauthorized address
    address minter1 = makeAddr("MINTER1"); // an authorized minter

    event EntityRegistered(address indexed entity);
    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event CreditAdded(address indexed entity, uint256 amount);
    event CreditDeducted(address indexed entity, uint256 amount);
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

    function setUp() public {
        HelperConfig helper = new HelperConfig();
        config = helper.getActiveNetworkConfig();

        registry = new CreditUnitRegistry(config.initialOwner);
    }

    modifier asOwner() {
        vm.startPrank(config.initialOwner);
        _;
        vm.stopPrank();
    }

    modifier authorizedMinter() {
        // Arrange: authorize minter1
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTER ENTITY TESTS
    //////////////////////////////////////////////////////////////*/

    function testOwnerIsCorrect() public view {
        assertEq(registry.owner(), config.initialOwner);
    }

    function testRegistryEntity() public asOwner {
        // Owner registers entity
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );

        // Check storage
        assertTrue(registry.registered(entity1));

        CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
            entity1
        );
        assertEq(credit.totalMinted, 0);
        assertEq(credit.totalRetired, 0);
    }

    function testRegistryEntityRevertZeroAddress() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InvalidEntity.selector,
                address(0)
            )
        );
        registry.registerEntity(
            address(0),
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://exampleCID"
        );

        assertFalse(registry.registered(address(0)));
    }

    function testRegistryEntityRevertDoubleRegistration() public asOwner {
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.AlreadyRegistered.selector,
                entity1
            )
        );
        registry.registerEntity(
            entity1,
            "P-002",
            2025,
            "VCS-002",
            "Gold Standard",
            "ipfs://cid2"
        );

        CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
            entity1
        );
        assertEq(credit.projectId, "P-001");
        assertEq(credit.vintage, 2024);
        assertEq(credit.totalMinted, 0);
        assertEq(credit.totalRetired, 0);
    }

    function testRegisterEntityRevertEmptyProjectId() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "projectId"
            )
        );
        registry.registerEntity(
            entity1,
            "",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertEmptyMethodology() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "methodology"
            )
        );
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "",
            "Verra",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertEmptyVerifier() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "verifier"
            )
        );
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        ); // matches OZ Ownable
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );

        assertFalse(registry.registered(entity1));
    }

    function testRegisterEntityEmitsEvent() public asOwner {
        vm.expectEmit(true, true, true, true);
        emit EntityRegistered(entity1);
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertsEmptyProjectId() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "projectId"
            )
        );
        registry.registerEntity(
            entity1,
            "",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertsEmptyMethodology() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "methodology"
            )
        );
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "",
            "Verra",
            "ipfs://cid"
        );
    }

    function testRegisterEntityRevertsEmptyVerifier() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.EmptyField.selector,
                "verifier"
            )
        );
        registry.registerEntity(
            entity1,
            "P-001",
            2024,
            "VCS-001",
            "",
            "ipfs://cid"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED MINTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function testAuthorizedMinterSetByOwner() public asOwner {
        vm.expectEmit(true, true, true, true);
        emit AuthorizedMinterSet(minter1, true);

        registry.authorizedMintersAdd(minter1, true);

        assertTrue(registry.authorizedMinters(minter1));
    }

    function testAuthorizedMinterRevertZeroAddress() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InvalidEntity.selector,
                address(0)
            )
        );

        registry.authorizedMintersAdd(address(0), true);
    }

    function testAuthorizedMinterRevertNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );

        registry.authorizedMintersAdd(minter1, true);
    }

    function testAuthorizedMinterUnset() public asOwner {
        // First set → expect AuthorizedMinterSet(minter1, true)
        vm.expectEmit(true, true, true, true);
        emit CreditUnitRegistry.AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        assertTrue(registry.authorizedMinters(minter1));

        // Then unset → expect AuthorizedMinterSet(minter1, false)
        vm.expectEmit(true, true, true, true);
        emit CreditUnitRegistry.AuthorizedMinterSet(minter1, false);
        registry.authorizedMintersAdd(minter1, false);
        assertFalse(registry.authorizedMinters(minter1));
    }

    function testAuthorizedMintersAddRevertsOnZeroAddress() public asOwner {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InvalidEntity.selector,
                address(0)
            )
        );
        registry.authorizedMintersAdd(address(0), true);

        assert(registry.authorizedMinters(address(0)) == false);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD CREDIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testAddCreditByAuthorizedMinter() public authorizedMinter {
        // Arrange: authorize minter1
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Act: minter1 adds credit to entity1
        vm.prank(minter1);
        vm.expectEmit(true, true, false, true, address(registry));
        emit CreditsMinted(entity1, minter1, 100, 100);
        registry.addCredit(entity1, 100);

        // Assert: storage updated
        assertEq(registry.getCredit(entity1).totalMinted, 100);
    }

    function testAddCreditRevertInvalidEntity() public authorizedMinter {
        // Arrange: authorize minter1
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Act: call with zero address
        vm.prank(minter1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InvalidEntity.selector,
                address(0)
            )
        );
        registry.addCredit(address(0), 100);

        CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
            address(0)
        );
        assertEq(credit.totalMinted, 0);
        assertEq(credit.totalRetired, 0);
    }

    function testAddCreditRevertInvalidAmount() public authorizedMinter {
        // Arrange: authorize minter1
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Act: call with amount = 0
        vm.prank(minter1);
        vm.expectRevert(
            abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
        );
        registry.addCredit(entity1, 0);

        assertEq(registry.getCredit(entity1).totalMinted, 0);
    }

    function testAddCreditRevertUnauthorized() public {
        // Act: attacker (not authorized) calls addCredit
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.NotAuthorized.selector,
                attacker
            )
        );
        registry.addCredit(entity1, 100);

        assertEq(registry.getCredit(entity1).totalMinted, 0);
    }

    function testAddCreditRevertsOnZeroAmount() public authorizedMinter {
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        vm.prank(minter1);
        vm.expectRevert(
            abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
        );
        registry.addCredit(entity1, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        DEDUCT CREDIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeductCreditByOwner() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);

        // Mint credits
        vm.prank(minter1);
        registry.addCredit(entity1, 100);

        // Act: owner deducts 50
        vm.prank(config.initialOwner);
        vm.expectEmit(true, true, true, true);
        emit CreditDeducted(entity1, 50);
        registry.deductCredit(entity1, 50);

        // Assert: retired credits updated
        assertEq(registry.getCredit(entity1).totalRetired, 50);
    }

    function testDeductCreditRevertInsufficientCredits() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);
        // Arrange: mint only 100

        vm.prank(minter1);
        registry.addCredit(entity1, 100);

        // Act: try retiring 200
        vm.prank(config.initialOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InsufficientCredits.selector,
                100,
                200
            )
        );

        registry.deductCredit(entity1, 200);

        assertEq(registry.getCredit(entity1).totalRetired, 0);
    }

    function testDeductCreditRevertInvalidAmount() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);
        // Act: retire 0 → invalid
        vm.expectRevert(
            abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
        );

        vm.prank(config.initialOwner);
        registry.deductCredit(entity1, 0);

        assertEq(registry.getCredit(entity1).totalRetired, 0);
    }

    function testDeductCreditRevertUnauthorizedCaller() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );
        registry.deductCredit(entity1, 50);

        assertEq(registry.getCredit(entity1).totalRetired, 0);
    }

    function testDeductCreditRevertsOnZeroAmount() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);

        vm.expectRevert(
            abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
        );

        vm.prank(config.initialOwner);
        registry.deductCredit(entity1, 0);

        assertEq(registry.getCredit(entity1).totalRetired, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        GETTER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetCreditReturnsStorageData() public authorizedMinter {
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);
        // Arrange: mint credits first
        vm.prank(minter1);
        registry.addCredit(entity1, 100);

        // Act: get credit
        CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
            entity1
        );

        // Assert
        assertEq(credit.totalMinted, 100);
        assertEq(credit.totalRetired, 0);
    }

    function testAvailableCreditsUnregisteredEntity() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.UnregisteredEntity.selector,
                entity1 // include the address argument expected by the error
            )
        );
        // Call the function that should revert
        uint256 available = registry.availableCredits(entity1);
        assertEq(available, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        RETIRED FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testRetireCreditsSuccess() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);

        vm.prank(minter1);
        registry.addCredit(entity1, 100);

        vm.prank(minter1);
        vm.expectEmit(true, true, true, true);
        emit CreditsRetired(entity1, minter1, 40, 40);

        registry.retiredCredits(entity1, 40);

        // Assert state
        assertEq(registry.getCredit(entity1).totalMinted, 100);
        assertEq(registry.getCredit(entity1).totalRetired, 40);
        assertEq(
            registry.availableCredits(entity1),
            60 // available left
        );
    }

    function testRetireCreditsRevertUnregisteredEntity() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.UnregisteredEntity.selector,
                minter1
            )
        );

        vm.prank(config.initialOwner);
        registry.retiredCredits(minter1, 10);
    }

    function testRetireCreditsRevertInsufficientCredits() public {
        // Arrange: register entity first
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        // Give minter rights
        vm.prank(config.initialOwner);
        registry.authorizedMintersAdd(minter1, true);

        vm.prank(minter1);
        registry.addCredit(entity1, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InsufficientCredits.selector,
                100, // available
                200 // requested
            )
        );

        vm.prank(config.initialOwner);
        registry.retiredCredits(entity1, 200);
    }

    function testRetireCreditsRevertUnauthorizedMinter() public {
        // Arrange: register entity so revert comes only from minter check
        vm.prank(config.initialOwner);
        registry.addEntity(entity1);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.NotAuthorized.selector,
                attacker
            )
        );

        registry.retiredCredits(entity1, 10);
    }
}
