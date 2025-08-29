// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {CreditUnitRegistry} from "../../src/registry/CreditUnitRegistry.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract CreditUnitRegistryFlowTest is Test {
    CreditUnitRegistry registry;
    HelperConfig.NetworkConfig config;

    address owner;
    address minter1 = makeAddr("MINTER1");
    address entityA = makeAddr("ENTITY_A");
    address entityB = makeAddr("ENTITY_B");
    address attacker = makeAddr("ATTACKER");

    // Events (copy signatures from the contract)
    event EntityRegistered(address indexed entity);
    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event CreditAdded(address indexed entity, uint256 amount);
    event CreditsMinted(
        address indexed entity,
        address indexed by,
        uint256 amount,
        uint256 cumulative
    );
    event CreditDeducted(address indexed entity, uint256 amount);

    function setUp() public {
        HelperConfig helper = new HelperConfig();
        config = helper.getActiveNetworkConfig();
        owner = config.initialOwner;

        // deploy fresh registry per test
        registry = new CreditUnitRegistry(owner);
    }

    // handy modifiers to keep tests readable
    modifier asOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }
    modifier withAuthorizedMinter() {
        vm.prank(owner);
        registry.authorizedMintersAdd(minter1, true);
        _;
    }

    function testIntegrationSingleEntity() public asOwner {
        // 1) Register entityA
        // topics: [event sig][entityA]; so check topic1 (indexed) + data
        vm.expectEmit(true, false, false, false, address(registry));
        emit EntityRegistered(entityA);
        registry.registerEntity(
            entityA,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );

        assertTrue(registry.registered(entityA));
        assertEq(registry.getCredit(entityA).totalMinted, 0);
        assertEq(registry.getCredit(entityA).totalRetired, 0);

        // 2) Authorize minter1
        vm.expectEmit(true, false, false, false, address(registry));
        emit AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        assertTrue(registry.authorizedMinters(minter1));

        // 3) minter1 adds 100
        vm.expectEmit(true, false, false, false, address(registry));
        emit CreditsMinted(entityA, owner, 100, 100);
        registry.addCredit(entityA, 100);

        assertEq(registry.getCredit(entityA).totalMinted, 100);
        assertEq(registry.availableCredits(entityA), 100);

        // 4) owner retires 60
        vm.expectEmit(true, false, false, false, address(registry));
        emit CreditDeducted(entityA, 60);
        registry.deductCredit(entityA, 60);

        assertEq(registry.getCredit(entityA).totalRetired, 60);
        assertEq(registry.availableCredits(entityA), 40);
    }

    function testIntegrationAuthorizationFlip() public {
        vm.startPrank(owner);
        // Register & authorize
        registry.registerEntity(
            entityA,
            "P-001",
            2024,
            "VCS-001",
            "Verra",
            "ipfs://cid"
        );
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        vm.stopPrank();

        vm.startPrank(minter1);
        registry.addCredit(entityA, 100);
        vm.stopPrank();

        // Revoke
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(minter1, false);
        registry.authorizedMintersAdd(minter1, false);
        vm.stopPrank();
        assertFalse(registry.authorizedMinters(minter1));

        // Now minter1 is blocked
        vm.startPrank(minter1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.NotAuthorized.selector,
                minter1
            )
        );
        registry.addCredit(entityA, 50);
        vm.stopPrank();

        // Re-authorize
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        vm.stopPrank();

        // Works again
        vm.startPrank(minter1);
        registry.addCredit(entityA, 50);
        vm.stopPrank();

        assertEq(registry.getCredit(entityA).totalMinted, 150);
    }

    function testIntegrationMultiEntityIsolation() public {
        vm.startPrank(owner);
        registry.registerEntity(
            entityA,
            "P-A",
            2023,
            "M-A",
            "Verra",
            "ipfs://A"
        );
        registry.registerEntity(
            entityB,
            "P-B",
            2025,
            "M-B",
            "Gold",
            "ipfs://B"
        );
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        vm.stopPrank();

        vm.startPrank(minter1);
        registry.addCredit(entityA, 100);
        registry.addCredit(entityB, 25);
        vm.stopPrank();

        vm.startPrank(owner);
        registry.deductCredit(entityA, 60);
        registry.deductCredit(entityB, 10);
        vm.stopPrank();

        assertEq(registry.availableCredits(entityA), 40);
        assertEq(registry.availableCredits(entityB), 15);
    }

    function testIntegrationExactRetireThenFail() public {
        vm.startPrank(owner);
        registry.registerEntity(entityA, "P-EX", 2024, "M", "V", "ipfs://x");
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(minter1, true);
        registry.authorizedMintersAdd(minter1, true);
        vm.stopPrank();

        vm.prank(minter1);
        registry.addCredit(entityA, 80);

        // retire exactly 80
        vm.startPrank(owner);
        registry.deductCredit(entityA, 80);
        assertEq(registry.availableCredits(entityA), 0);

        // next retire fails
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.InsufficientCredits.selector,
                0,
                1
            )
        );
        registry.deductCredit(entityA, 1);
        vm.stopPrank();
    }

    function testIntegrationContractAsMinter() public {
        vm.startPrank(owner);
        MockMinter mock = new MockMinter();
        registry.registerEntity(entityA, "P-001", 2024, "M", "V", "ipfs://cid");

        // authorize the mock contract
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(address(mock), true);
        registry.authorizedMintersAdd(address(mock), true);
        vm.stopPrank();

        // call from the mock’s address (prank as the mock)
        vm.prank(address(mock));
        registry.addCredit(entityA, 33);
        assertEq(registry.getCredit(entityA).totalMinted, 33);

        vm.prank(owner); // some arbitrary EOA
        mock.pushMint(registry, entityA, 10);
        assertEq(registry.getCredit(entityA).totalMinted, 43);

        // revoke and prove blocked
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true, address(registry));
        emit AuthorizedMinterSet(address(mock), false);
        registry.authorizedMintersAdd(address(mock), false);
        vm.stopPrank();

        vm.prank(address(mock));
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditUnitRegistry.NotAuthorized.selector,
                address(mock)
            )
        );
        registry.addCredit(entityA, 1);
    }
}

contract MockMinter {
    function pushMint(
        CreditUnitRegistry r,
        address entity,
        uint256 amt
    ) external {
        r.addCredit(entity, amt);
    }
}
