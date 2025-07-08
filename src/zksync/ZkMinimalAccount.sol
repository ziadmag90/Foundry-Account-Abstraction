// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "foundry-era-contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "foundry-era-contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "foundry-era-contracts/Constants.sol";
import {INonceHolder} from "foundry-era-contracts/interfaces/INonceHolder.sol";
import {Utils} from "foundry-era-contracts/libraries/Utils.sol";

import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";

contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    // Errors
    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootloader();
    error ZkMinimalAccount__NotFromBootloaderOrOwner();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();

    // Modifiers
    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootloader();
        }
        _;
    }

    modifier requireFromBootloaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootloaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable {}
    // External Function

    function validateTransaction(
        bytes32, /* _txHash*/
        bytes32, /* _suggestedSignedHash*/
        Transaction memory _transaction
    ) external payable requireFromBootloader returns (bytes4 magic) {
        magic = _validateTransaction(_transaction);
    }

    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootloaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32, /*_txHash*/ bytes32, /*_possibleSignedHash*/ Transaction memory _transaction)
        external
        payable
    {}

    // Internal Functions
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );
        // Check for fee to Pay
        uint256 totalRequireBalance = _transaction.totalRequiredBalance();
        if (totalRequireBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Check the signature and return magic
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        if (signer == owner()) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }
}
