//SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";
import {
    SendPackedUserOp, PackedUserOperation, IEntryPoint, MessageHashUtils
} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test {
    MinimalAccount public minimalaccount;
    DeployMinimal public deployer;
    HelperConfig public helper;
    ERC20Mock public usdc;
    SendPackedUserOp public sendPackedUserOp;

    address ziad = makeAddr("ziad");
    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        deployer = new DeployMinimal();
        (helper, minimalaccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecute() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalaccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalaccount), AMOUNT);
        // you can use this as well -> bytes memory functionData = abi.encodeWithSelector(bytes4(keccak256("mint(address, uint256)")), address(minimalaccount), AMOUNT);

        // Act
        vm.prank(minimalaccount.owner());
        minimalaccount.execute(dest, value, functionData);
        // Assert
        assertEq(usdc.balanceOf(address(minimalaccount)), AMOUNT);
    }

    function testCanNotOwnerExecute() public {
        // Arrange
        assertEq(usdc.balanceOf(ziad), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalaccount), AMOUNT);

        // Act
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        vm.prank(ziad);
        minimalaccount.execute(dest, value, functionData);

        // Assert
        assert(usdc.balanceOf(ziad) == 0);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalaccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalaccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOperation(executeCallData, helper.getConfig(), address(minimalaccount));
        // Act
        bytes32 userOpHash = IEntryPoint(helper.getConfig().entryPoint).getUserOpHash(packedUserOp);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        bytes memory signature = packedUserOp.signature;
        address signer = ECDSA.recover(digest, signature);

        // Assert
        console.log("owner: ", minimalaccount.owner());
        assertEq(signer, minimalaccount.owner()); // assertEq(signer, helper.getConfig().account);
    }

    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalaccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalaccount), AMOUNT);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOperation(executeCallData, helper.getConfig(), address(minimalaccount));
        bytes32 userOpHash = IEntryPoint(helper.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;
        // Act
        vm.startPrank(helper.getConfig().entryPoint);
        uint256 actualValidationData = minimalaccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        vm.stopPrank();
        uint256 expectedValidationData = 0;
        // Assert
        assertEq(actualValidationData, expectedValidationData);
    }

    function testEntryPointCanExecute() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalaccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalaccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOperation(executeCallData, helper.getConfig(), address(minimalaccount));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.deal(address(minimalaccount), 1e18);

        // Act
        vm.prank(ziad);
        IEntryPoint(helper.getConfig().entryPoint).handleOps(ops, payable(ziad));
        // Assert
        assertEq(usdc.balanceOf(address(minimalaccount)), AMOUNT);
    }
}
