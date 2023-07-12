// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SweetToken is ERC20 {
  address public minter;

  constructor() payable ERC20('Sweet Token', 'SWT') {
    minter = msg.sender;
  }

  function mint(address _account, uint256 _amount) public {
    _mint(_account, _amount);
  }
}
