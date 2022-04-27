// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// Relay request with built-in MetaTx support with signature verification on behalf of user
// In case a sponsor (other than user) wants to pay for the tx,
// we will also need to verify sponsor's signature
struct MetaTxRequest {
    uint256 chainId;
    address target;
    bytes data;
    address feeToken;
    uint256 paymentType;
    uint256 maxFee;
    address user;
    address sponsor; // could be same as user
    uint256 nonce;
    uint256 deadline;
    bool isEIP2771;
}

// Similar to MetaTxRequest, but no need to implement user-specific signature verification logic
// Only sponsor signature is verified in order to ensure integrity of fee payments
struct ForwardedRequest {
    uint256 chainId;
    address target;
    bytes data;
    address feeToken;
    uint256 paymentType;
    uint256 maxFee;
    address sponsor;
    uint256 nonce;
}
