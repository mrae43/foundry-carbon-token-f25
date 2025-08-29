// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {CreditUnitRegistry} from "../../src/CreditUnitRegistry.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// contract CreditUnitRegistryTest is Test {
//     CreditUnitRegistry registry;
//     HelperConfig.NetworkConfig config;

//     address entity1 = makeAddr("USER");
//     address attacker = makeAddr("ATTACKER");
//     address minter1 = makeAddr("MINTER1");

//     event EntityRegistered(address indexed entity);
//     event AuthorizedMinterSet(address indexed minter, bool allowed);
//     event CreditAdded(address indexed entity, uint256 amount);
//     event CreditDeducted(address indexed entity, uint256 amount);

//     function setUp() public {
//         HelperConfig helper = new HelperConfig();
//         config = helper.getActiveNetworkConfig();
//         registry = new CreditUnitRegistry(config.initialOwner);
//     }

//     modifier asOwner() {
//         vm.startPrank(config.initialOwner);
//         _;
//         vm.stopPrank();
//     }

//     modifier authorizedMinter() {
//         vm.prank(config.initialOwner);
//         registry.authorizedMintersAdd(minter1, true);
//         _;
//     }

//     /*//////////////////////////////////////////////////////////////
//                         REGISTER ENTITY TESTS
//     //////////////////////////////////////////////////////////////*/
//     function testOwnerIsCorrect() public view {
//         assertEq(registry.owner(), config.initialOwner);
//     }

//     function testRegisterEntitySuccess() public asOwner {
//         vm.expectEmit(true, true, true, true);
//         emit EntityRegistered(entity1);

//         registry.registerEntity(
//             entity1,
//             "P-001",
//             2024,
//             "VCS-001",
//             "Verra",
//             "ipfs://cid"
//         );

//         assertTrue(registry.registered(entity1));
//         CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
//             entity1
//         );
//         assertEq(credit.totalMinted, 0);
//         assertEq(credit.totalRetired, 0);
//     }

//     function testRegisterEntityReverts() public asOwner {
//         // Zero address
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.InvalidEntity.selector,
//                 address(0)
//             )
//         );
//         registry.registerEntity(
//             address(0),
//             "P-001",
//             2024,
//             "VCS-001",
//             "Verra",
//             "ipfs://cid"
//         );

//         // Duplicate registration
//         registry.registerEntity(
//             entity1,
//             "P-001",
//             2024,
//             "VCS-001",
//             "Verra",
//             "ipfs://cid"
//         );
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.AlreadyRegistered.selector,
//                 entity1
//             )
//         );
//         registry.registerEntity(
//             entity1,
//             "P-002",
//             2025,
//             "VCS-002",
//             "Gold Standard",
//             "ipfs://cid2"
//         );

//         // Empty fields
//         string[3] memory fields = ["projectId", "methodology", "verifier"];
//         // string[3] memory values = ["", "VCS-001", "Verra"];
//         for (uint i = 0; i < fields.length; i++) {
//             string memory projectId = i == 0 ? "" : "P-001";
//             string memory methodology = i == 1 ? "" : "VCS-001";
//             string memory verifier = i == 2 ? "" : "Verra";

//             vm.expectRevert(
//                 abi.encodeWithSelector(
//                     CreditUnitRegistry.EmptyField.selector,
//                     fields[i]
//                 )
//             );
//             registry.registerEntity(
//                 entity1,
//                 projectId,
//                 2024,
//                 methodology,
//                 verifier,
//                 "ipfs://cid"
//             );
//         }
//     }

//     function testRegisterEntityRevertNonOwner() public {
//         vm.prank(attacker);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Ownable.OwnableUnauthorizedAccount.selector,
//                 attacker
//             )
//         );
//         registry.registerEntity(
//             entity1,
//             "P-001",
//             2024,
//             "VCS-001",
//             "Verra",
//             "ipfs://cid"
//         );
//     }

//     /*//////////////////////////////////////////////////////////////
//                         AUTHORIZED MINTERS TESTS
//     //////////////////////////////////////////////////////////////*/
//     function testAuthorizedMintersAddAndUnset() public asOwner {
//         // Set
//         vm.expectEmit(true, true, true, true);
//         emit AuthorizedMinterSet(minter1, true);
//         registry.authorizedMintersAdd(minter1, true);
//         assertTrue(registry.authorizedMinters(minter1));

//         // Unset
//         vm.expectEmit(true, true, true, true);
//         emit AuthorizedMinterSet(minter1, false);
//         registry.authorizedMintersAdd(minter1, false);
//         assertFalse(registry.authorizedMinters(minter1));
//     }

//     function testAuthorizedMintersReverts() public {
//         // Zero address
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.InvalidEntity.selector,
//                 address(0)
//             )
//         );
//         registry.authorizedMintersAdd(address(0), true);

//         // Non-owner
//         vm.prank(attacker);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Ownable.OwnableUnauthorizedAccount.selector,
//                 attacker
//             )
//         );
//         registry.authorizedMintersAdd(minter1, true);
//     }

//     /*//////////////////////////////////////////////////////////////
//                         ADD CREDIT TESTS
//     //////////////////////////////////////////////////////////////*/
//     function testAddCreditSuccess() public authorizedMinter {
//         vm.prank(minter1);
//         vm.expectEmit(true, true, true, true);
//         emit CreditAdded(entity1, 100);
//         registry.addCredit(entity1, 100);

//         assertEq(registry.getCredit(entity1).totalMinted, 100);
//     }

//     function testAddCreditReverts() public {
//         // Unauthorized
//         vm.prank(attacker);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.NotAuthorized.selector,
//                 attacker
//             )
//         );
//         registry.addCredit(entity1, 100);

//         // Invalid entity
//         vm.prank(minter1);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.InvalidEntity.selector,
//                 address(0)
//             )
//         );
//         registry.addCredit(address(0), 100);

//         // Zero amount
//         vm.prank(minter1);
//         vm.expectRevert(
//             abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
//         );
//         registry.addCredit(entity1, 0);
//     }

//     /*//////////////////////////////////////////////////////////////
//                         DEDUCT CREDIT TESTS
//     //////////////////////////////////////////////////////////////*/
//     function testDeductCreditSuccess() public authorizedMinter asOwner {
//         // Mint first
//         vm.prank(minter1);
//         registry.addCredit(entity1, 100);

//         // Deduct
//         vm.expectEmit(true, true, true, true);
//         emit CreditDeducted(entity1, 50);
//         registry.deductCredit(entity1, 50);

//         assertEq(registry.getCredit(entity1).totalRetired, 50);
//     }

//     function testDeductCreditReverts() public {
//         // Mint first
//         vm.prank(minter1);
//         registry.addCredit(entity1, 100);

//         // Insufficient credits
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 CreditUnitRegistry.InsufficientCredits.selector,
//                 100,
//                 200
//             )
//         );
//         vm.startPrank(config.initialOwner);
//         registry.deductCredit(entity1, 200);
//         vm.stopPrank();

//         // Zero amount
//         vm.expectRevert(
//             abi.encodeWithSelector(CreditUnitRegistry.InvalidAmount.selector, 0)
//         );
//         vm.startPrank(config.initialOwner);
//         registry.deductCredit(entity1, 0);
//         vm.stopPrank();

//         // Non-owner
//         vm.prank(attacker);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 Ownable.OwnableUnauthorizedAccount.selector,
//                 attacker
//             )
//         );
//         registry.deductCredit(entity1, 50);
//     }

//     /*//////////////////////////////////////////////////////////////
//                         GETTER TESTS
//     //////////////////////////////////////////////////////////////*/
//     function testGetCreditReturnsStorage() public authorizedMinter {
//         vm.prank(minter1);
//         registry.addCredit(entity1, 100);

//         CreditUnitRegistry.CreditUnit memory credit = registry.getCredit(
//             entity1
//         );
//         assertEq(credit.totalMinted, 100);
//         assertEq(credit.totalRetired, 0);
//     }

//     function testAvailableCreditsUnregisteredEntity() public view {
//         assertEq(registry.availableCredits(entity1), 0);
//     }
// }
