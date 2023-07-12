// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SweetToken is ERC20 {

  constructor() payable ERC20("Sweet Token", "SWT") {

  }
}
