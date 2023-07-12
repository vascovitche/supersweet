// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import "./SweetToken.sol";

contract Vote {

    SweetToken token;
    uint8 public interest = 10;
    uint public expiration = 30;
    uint public fullExpiration = 60 * 60 * 24 * 365;
    uint public partExpiration = 60 * 60 * 24 * 30;
//    uint public expiration = 60 * 60 * 24 * 30;

    mapping(address => address) owners;
    mapping(string => uint) heroes; // hero name => votes

    mapping(address => mapping(uint256 => uint256)) public deposits; // address => [block.timestamp => msg.value]
    mapping(address => uint256) public depositsCount; // address => id(counted++);
    mapping(address => mapping(uint256 => uint256)) public depositIDTimes; // address => [id(counted++) => block.timestamp]
    mapping(address => mapping(uint256 => string)) public depositFavorite; // address => [id(counted++) => hero]

    mapping(address => mapping(uint256 => uint256)) public withdrawIDTimes; // address => [id(counted++) => block.timestamp]
    mapping(address => mapping(uint256 => uint256)) public withdrawAmount; // address => [id(counted++) => amount]

    modifier onlyOwners() {
        require(owners[msg.sender] != address(0), 'Only owners can set new admin.');
        _;
    }

    constructor(SweetToken _token, string memory _hero1, string memory _hero2) {
        owners[msg.sender] = msg.sender;

        token = _token;
        heroes[_hero1] = 100;
        heroes[_hero2] = 100;
    }

    function setOwner(address _owner) public onlyOwners {
        owners[_owner] = _owner;
    }

    function deposit(string memory _heroName) public payable {
        require(heroes[_heroName] >= 100, 'Hero not found.');

        uint count = depositsCount[msg.sender] + 1;
        uint time = block.timestamp;

        deposits[msg.sender][time] = msg.value;
        depositsCount[msg.sender] = count;
        depositIDTimes[msg.sender][count] = time;
        depositFavorite[msg.sender][count] = _heroName;

        heroes[_heroName] = heroes[_heroName] + msg.value;
    }

    function withdraw(address payable _holder, uint _depositID) public payable {
        require(msg.sender == _holder, 'Only owner can withdraw.');

        uint depositStart = depositIDTimes[_holder][_depositID];
        require(depositStart != 0, 'Deposit not found.');

        uint time = block.timestamp;
        uint depositTime = time - depositStart;
        uint lastWithdrawTime = time - withdrawIDTimes[_holder][_depositID];

        require(lastWithdrawTime >= partExpiration || depositTime >= partExpiration, 'Can not withdraw yet.');

        uint amount = deposits[_holder][depositStart];

        uint interestAmount = amount * interest / 100;
        uint interestPerSecond = interestAmount / fullExpiration;
        uint withdrawInterest = interestPerSecond * lastWithdrawTime;

        token.mint(_holder, withdrawInterest);

        withdrawIDTimes[_holder][_depositID] = time;
        withdrawAmount[_holder][_depositID] = withdrawAmount[_holder][_depositID] + withdrawInterest;
    }

    function withdrawAllDeposit(address payable _holder, uint _depositID) public payable {
        require(msg.sender == _holder, 'Only owner can withdraw.');

        uint depositStart = depositIDTimes[_holder][_depositID];
        require(depositStart != 0, 'Deposit not found.');

        uint time = block.timestamp;
        uint depositTime = time - depositStart;

        require(depositTime >= fullExpiration, 'Can not withdraw yet.');

        uint amount = deposits[_holder][depositStart];
        uint interestAmount = amount * interest / 100;
        uint totalAmount = amount + interestAmount - withdrawAmount[_holder][_depositID];

        _holder.transfer(amount);
        token.mint(_holder, interestAmount);
        deposits[_holder][depositStart] = 0;
        withdrawAmount[_holder][_depositID] = 0;

        heroes[depositFavorite[_holder][_depositID]] = heroes[depositFavorite[_holder][_depositID]] - amount;
    }

}
