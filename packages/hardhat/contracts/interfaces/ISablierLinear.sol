// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @title ISablierLinear
interface ISablierLinear {
	/// @notice Retrieves the stream's recipient.
	/// @dev Reverts if the NFT has been burned.
	/// @param streamId The stream id for the query.
	function getRecipient(
		uint256 streamId
	) external view returns (address recipient);

	/// @notice Retrieves the stream entity.
	/// @dev Reverts if `streamId` references a null stream.
	/// @param streamId The stream id for the query.
	function getStream(
		uint256 streamId
	) external view returns (LockupLinear.Stream memory stream);

	/// @notice Calculates the amount that the recipient can withdraw from the stream, denoted in units of the asset's
	/// decimals.
	/// @dev Reverts if `streamId` references a null stream.
	/// @param streamId The stream id for the query.
	function withdrawableAmountOf(
		uint256 streamId
	) external view returns (uint128 withdrawableAmount);

	/// @notice Counter for stream ids, used in the create functions.
	function nextStreamId() external view returns (uint256);

	/// @notice Creates a stream by setting the start time to `block.timestamp`, and the end time to
	/// the sum of `block.timestamp` and `params.durations.total`. The stream is funded by `msg.sender` and is wrapped
	/// in an ERC-721 NFT.
	///
	/// @dev Emits a {Transfer} and {CreateLockupLinearStream} event.
	///
	/// Requirements:
	/// - All requirements in {createWithRange} must be met for the calculated parameters.
	///
	/// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
	/// @return streamId The id of the newly created stream.
	function createWithDurations(
		LockupLinear.CreateWithDurations calldata params
	) external returns (uint256 streamId);

	/// @notice Creates a stream with the provided start time and end time as the range. The stream is
	/// funded by `msg.sender` and is wrapped in an ERC-721 NFT.
	///
	/// @dev Emits a {Transfer} and {CreateLockupLinearStream} event.
	///
	/// Notes:
	/// - As long as the times are ordered, it is not an error for the start or the cliff time to be in the past.
	///
	/// Requirements:
	/// - Must not be delegate called.
	/// - `params.totalAmount` must be greater than zero.
	/// - If set, `params.broker.fee` must not be greater than `MAX_FEE`.
	/// - `params.range.start` must be less than or equal to `params.range.cliff`.
	/// - `params.range.cliff` must be less than `params.range.end`.
	/// - `params.range.end` must be in the future.
	/// - `params.recipient` must not be the zero address.
	/// - `msg.sender` must have allowed this contract to spend at least `params.totalAmount` assets.
	///
	/// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
	/// @return streamId The id of the newly created stream.
	function createWithRange(
		LockupLinear.CreateWithRange calldata params
	) external returns (uint256 streamId);

	/// @param streamId The id of the stream to withdraw from.
	/// @param to The address receiving the withdrawn assets.
	/// @param amount The amount to withdraw, denoted in units of the asset's decimals.
	function withdraw(uint256 streamId, address to, uint128 amount) external;
}
