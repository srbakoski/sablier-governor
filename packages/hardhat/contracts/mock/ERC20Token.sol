// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract ERC20Token is ERC20, ERC20Permit, ERC20Votes {
	constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}

	// This is a helper function to mint tokens for tests
	function mint(address to, uint256 amount) external {
		_mint(to, amount);
		// Activate voting power on mint
		_delegate(to, to);
	}

	// The functions below are overrides required by Solidity.
	function _afterTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Votes) {
		super._afterTokenTransfer(from, to, amount);
	}

	function _mint(
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Votes) {
		super._mint(to, amount);
	}

	function _burn(
		address account,
		uint256 amount
	) internal override(ERC20, ERC20Votes) {
		super._burn(account, amount);
	}
}
