// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

uint8 constant L3_MSG = 3;
uint8 constant L2MessageType_L3FundedByL2 = 7;
uint8 constant L2MessageType_submitRetryableTx = 9;
uint8 constant L2MessageType_ethDeposit = 12;
uint8 constant L2MessageType_batchPostingReport = 13;
uint8 constant L3MessageType_unsignedEOATx = 0;
uint8 constant L3MessageType_unsignedContractTx = 1;
uint8 ROLLUP_PROTOCOL_EVENT_TYPE = 8;
uint8 INITIALIZATION_MSG_TYPE =11;