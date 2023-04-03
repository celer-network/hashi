// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import "../HeaderStorage.sol";
import "./base/BaseMessageSender.sol";

contract CelerHeaderReporter is BaseMessageSender {
    HeaderStorage public immutable headerStorage;

    event HeaderReported(address indexed emitter, uint256 indexed blockNumber, bytes32 indexed blockHeader);

    constructor(address _msgBus, HeaderStorage _headerStorage) BaseMessageSender(_msgBus) {
        headerStorage = _headerStorage;
    }

    /// @dev Reports the given block headers to the oracleAdapter.
    /// @param blockNumbers Uint256 array of block number to pass.
    /// @param dstChainId Chain id of the oracle adapter to pass the header to.
    /// @param receipt Bytes32 receipt for the transaction.
    function reportHeaders(uint256[] memory blockNumbers, uint256 dstChainId) public returns (bytes32 receipt) {
        bytes32[] memory blockHeaders = headerStorage.storeBlockHeaders(blockNumbers);
        receipt = _getNewMessageId(dstChainId);
        _sendMessage(dstChainId, abi.encode(receipt, blockNumbers, blockHeaders));
        for (uint i = 0; i < blockNumbers.length; i++) {
            emit HeaderReported(address(this), blockNumbers[i], blockHeaders[i]);
        }
    }
}
