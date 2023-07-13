// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SweetToken.sol";

contract Vote {
    using SafeMath for uint;

    SweetToken token;
    uint8 public interest = 10;
//    uint public expiration = 30;
    // really time
    uint public fullExpiration = 60 * 60 * 24 * 365;
    uint public partExpiration = 60 * 60 * 24 * 30;

//    uint public expiration = 60 * 60 * 24 * 30;

    //test time
//    uint public fullExpiration = 60 * 5;
//    uint public partExpiration = 60 * 1;

    mapping(address => address) owners;
    mapping(string => uint) public heroes; // hero name => votes

    struct Deposit {
        uint amount;
        string hero;
        uint startAt;
    }

    mapping(address => mapping(uint => Deposit)) public deposits;
    mapping(address => uint) public depositsCount;

    struct Withdraw {
        uint time;
        uint totalAmount;
    }

    mapping(address => mapping(uint => Withdraw)) public withdraws;

//    mapping(address => mapping(uint256 => uint256)) public deposits; // address => [block.timestamp => msg.value]
//    mapping(address => uint256) public depositsCount; // address => id(counted++);
//    mapping(address => mapping(uint256 => uint256)) public depositIDTimes; // address => [id(counted++) => block.timestamp]
//    mapping(address => mapping(uint256 => string)) public depositFavorite; // address => [id(counted++) => hero]
//
//    mapping(address => mapping(uint256 => uint256)) public withdrawIDTimes; // address => [id(counted++) => block.timestamp]
//    mapping(address => mapping(uint256 => uint256)) public withdrawAmount; // address => [id(counted++) => amount]

    event Staking(address indexed user, uint amount, string hero, uint startAt);
    event PartWithdraw(address indexed user, uint interest, uint time);
    event FullWithdraw(address indexed user, uint amount, uint interest, uint time);
    event HeroVotePlus(address indexed user, string hero, uint amount, uint time);
    event HeroVoteMinus(address indexed user, string hero, uint amount, uint time);


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

    function staking(string memory _hero) public payable {
        require(heroes[_hero] >= 100, 'Hero not found.');

        uint count = depositsCount[msg.sender].add(1);

        Deposit storage newDeposit = deposits[msg.sender][count];
        newDeposit.amount = msg.value;
        newDeposit.hero = _hero;
        newDeposit.startAt = block.timestamp;

        depositsCount[msg.sender] = count;

        emit Staking(msg.sender, msg.value, _hero, block.timestamp);

        heroes[_hero] = heroes[_hero] + msg.value;

        emit HeroVotePlus(msg.sender, _hero, msg.value, block.timestamp);
    }

    function getHolderDeposits(address _holder) public view returns(Deposit[] memory) {
        uint depositCount = depositsCount[_holder];

        Deposit[] memory holderDeposits = new Deposit[](depositCount.add(1));

        for (uint i = 0; i <= depositCount; i.add(1)) {
            Deposit memory data  = deposits[_holder][i];
            holderDeposits[i] = data;
        }

        return holderDeposits;
    }

    function partWithdraw(address payable _holder, uint _depositID) public payable {
        require(msg.sender == _holder, 'Only holder can withdraw.');

        Deposit memory deposit = deposits[_holder][_depositID];
        Withdraw memory withdraw = withdraws[_holder][_depositID];

        require(deposit.amount != 0, 'Deposit not found.');

        uint time = block.timestamp;
        uint depositTime = time.sub(deposit.startAt);
        uint lastWithdrawTime = time.sub(withdraw.time);

        require(lastWithdrawTime >= partExpiration || depositTime >= partExpiration, 'Can not withdraw yet.');

        uint amount = deposit.amount;

        uint interestAmount = amount.mul(interest).div(100);
        uint interestPerSecond = interestAmount.div(fullExpiration);
        uint withdrawInterest = interestPerSecond.mul(lastWithdrawTime);

        token.mint(_holder, withdrawInterest);

        withdraw.time = time;
        withdraw.totalAmount = withdraw.totalAmount.add(withdrawInterest);

        emit PartWithdraw(_holder, withdrawInterest, time);
    }

    function fullWithdraw(address payable _holder, uint _depositID) public payable {
        require(msg.sender == _holder, 'Only holder can withdraw.');

        Deposit memory deposit = deposits[_holder][_depositID];
        Withdraw memory withdraw = withdraws[_holder][_depositID];

        require(deposit.amount != 0, 'Deposit not found.');

        uint time = block.timestamp;
        uint depositTime = time.sub(deposit.startAt);

        require(depositTime >= fullExpiration, 'Can not withdraw yet.');

        uint amount = deposit.amount;
        uint interestAmount = amount.mul(interest).div(100);

        _holder.transfer(amount);
        token.mint(_holder, interestAmount);

        emit FullWithdraw(_holder, amount, interestAmount, time);

        deposit = Deposit(0, '', 0);
        withdraw = Withdraw(0, 0);

        heroes[deposit.hero] = heroes[deposit.hero].sub(amount);

        emit HeroVoteMinus(_holder, deposit.hero, amount, time);
    }

    function checkOwner(address _address) public view onlyOwners returns (address) {
        require(owners[_address] != address(0), 'This is not an owner.');
        return owners[_address];
    }

}
