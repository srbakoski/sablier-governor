// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @title ISablierDynamic
interface ISablierDynamic {
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
	) external view returns (LockupDynamic.Stream memory stream);

	/// @notice Calculates the amount that the recipient can withdraw from the stream, denoted in units of the asset's
	/// decimals.
	/// @dev Reverts if `streamId` references a null stream.
	/// @param streamId The stream id for the query.
	function withdrawableAmountOf(
		uint256 streamId
	) external view returns (uint128 withdrawableAmount);

	/// @notice Counter for stream ids, used in the create functions.
	function nextStreamId() external view returns (uint256);

	/// @notice Creates a stream by setting the start time to `block.timestamp`, and the end time to the sum of
	/// `block.timestamp` and all specified time deltas. The segment milestones are derived from these
	/// deltas. The stream is funded by `msg.sender` and is wrapped in an ERC-721 NFT.
	///
	/// @dev Emits a {Transfer} and {CreateLockupDynamicStream} event.
	///
	/// Requirements:
	/// - All requirements in {createWithMilestones} must be met for the calculated parameters.
	///
	/// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
	/// @return streamId The id of the newly created stream.
	function createWithDeltas(
		LockupDynamic.CreateWithDeltas calldata params
	) external returns (uint256 streamId);

	/// @notice Creates a stream with the provided segment milestones, implying the end time from the last milestone.
	/// The stream is funded by `msg.sender` and is wrapped in an ERC-721 NFT.
	///
	/// @dev Emits a {Transfer} and {CreateLockupDynamicStream} event.
	///
	/// Notes:
	/// - As long as the segment milestones are arranged in ascending order, it is not an error for some
	/// of them to be in the past.
	///
	/// Requirements:
	/// - Must not be delegate called.
	/// - `params.totalAmount` must be greater than zero.
	/// - If set, `params.broker.fee` must not be greater than `MAX_FEE`.
	/// - `params.segments` must have at least one segment, but not more than `MAX_SEGMENT_COUNT`.
	/// - `params.startTime` must be less than the first segment's milestone.
	/// - The segment milestones must be arranged in ascending order.
	/// - The last segment milestone (i.e. the stream's end time) must be in the future.
	/// - The sum of the segment amounts must equal the deposit amount.
	/// - `params.recipient` must not be the zero address.
	/// - `msg.sender` must have allowed this contract to spend at least `params.totalAmount` assets.
	///
	/// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
	/// @return streamId The id of the newly created stream.
	function createWithMilestones(
		LockupDynamic.CreateWithMilestones calldata params
	) external returns (uint256 streamId);

	/// @param streamId The id of the stream to withdraw from.
	/// @param to The address receiving the withdrawn assets.
	/// @param amount The amount to withdraw, denoted in units of the asset's decimals.
	function withdraw(uint256 streamId, address to, uint128 amount) external;

	/// @notice Cancels the stream and refunds any remaining assets to the sender.
	///
	/// @dev Emits a {Transfer}, {CancelLockupStream}, and {MetadataUpdate} event.
	///
	/// Notes:
	/// - If there any assets left for the recipient to withdraw, the stream is marked as canceled. Otherwise, the
	/// stream is marked as depleted.
	/// - This function attempts to invoke a hook on the recipient, if the resolved address is a contract.
	///
	/// Requirements:
	/// - Must not be delegate called.
	/// - The stream must be warm and cancelable.
	/// - `msg.sender` must be the stream's sender.
	///
	/// @param streamId The id of the stream to cancel.
	function cancel(uint256 streamId) external;
}
