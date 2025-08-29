// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICarbonCreditToken
/// @notice Interface for the CarbonCreditToken contract
/// @dev Provides a lightweight blueprint for external contracts to interact
interface ICarbonCreditToken {
    /// @notice Mint new carbon credit tokens
    /// @param to The address receiving the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens to represent retirement of carbon credits
    /// @param from The address whose tokens will be burned
    /// @param amount The amount of tokens to retire
    function burnForRetirement(address from, uint256 amount) external;
}
