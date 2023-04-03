// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import "../../interfaces/IMessageRelay.sol";
import "../../Yaho.sol";
import "./base/BaseMessageSender.sol";

contract CelerMessageRelayer is IMessageRelay, BaseMessageSender {
    Yaho public immutable yaho;
    uint256 public immutable dstChainId;

    event MessageRelayed(address indexed emitter, uint256 indexed messageId);

    constructor(address _msgBus, Yaho _yaho, uint256 _dstChainId, address _adapter) BaseMessageSender(_msgBus) {
        yaho = _yaho;
        dstChainId = _dstChainId;
        _updateReceiverAdapter(_dstChainId, _adapter);
    }

    /*
     * @inheritdoc IMessageRelay
     */
    function relayMessages(
        uint256[] memory messageIds,
        address adapter
    ) public payable override returns (bytes32 receipt) {
        require(receiverAdapters[dstChainId] == adapter, "not allowed adapter");
        bytes32[] memory hashes = new bytes32[](messageIds.length);
        for (uint i = 0; i < messageIds.length; i++) {
            uint256 id = messageIds[i];
            hashes[i] = yaho.hashes(id);
            emit MessageRelayed(address(this), messageIds[i]);
        }
        receipt = _getNewMessageId(dstChainId);
        _sendMessage(dstChainId, abi.encode(receipt, messageIds, hashes));
    }
}
