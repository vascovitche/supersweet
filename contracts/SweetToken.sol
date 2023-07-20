// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SweetToken is ERC20 {
  address public minter;

  modifier onlyMinter() {
    require(msg.sender == minter, 'Error, only minter can mint tokens');
    _;
  }

  constructor() payable ERC20('Sweet Token', 'SWT') {
    minter = msg.sender;
    _mint(msg.sender, 1000000000000000000000000000);
  }

  function newMinter(address _minter) public onlyMinter returns (bool) {
    minter = _minter;

    return true;
  }

  function mint(address _account, uint256 _amount) public onlyMinter {
    _mint(_account, _amount);
  }

//  function transferToDeposit(
//    address _from,
//    address _to,
//    uint256 _amount)
//  public payable {
//    _approve(_from, _to, 0);
//    _approve(_from, _to, _amount);
//    transferFrom(_from, _to, _amount);
//  }
}
