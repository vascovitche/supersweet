// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SweetToken.sol";

contract Vote {
    using SafeMath for uint;

    SweetToken public token;
    uint8 public interest = 10;

    uint public fullExpiration = 60 * 60 * 24 * 365;
    uint public partExpiration = 60 * 60 * 24 * 30;

    mapping(address => address) private owners;
    mapping(string => uint) public heroes; // hero name => votes

    struct Deposit {
        uint id;
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
        newDeposit.id = count;
        newDeposit.amount = msg.value;
        newDeposit.hero = _hero;
        newDeposit.startAt = block.timestamp;

        depositsCount[msg.sender] = count;

        emit Staking(msg.sender, msg.value, _hero, block.timestamp);

        heroes[_hero] = heroes[_hero].add(msg.value);

        emit HeroVotePlus(msg.sender, _hero, msg.value, block.timestamp);
    }

    function getHolderDeposits(address _holder) public view returns (Deposit[] memory) {
        uint depositCount = depositsCount[_holder];

        Deposit[] memory holderDeposits = new Deposit[](depositCount.add(1));

        for (uint i = 1; i <= depositCount; i++) {
            Deposit memory data = deposits[_holder][i];
            holderDeposits[i] = data;
        }

        return holderDeposits;
    }

    function partWithdraw(uint _depositID) public payable {

        Deposit memory deposit = deposits[msg.sender][_depositID];
        Withdraw memory withdraw = withdraws[msg.sender][_depositID];

        require(deposit.amount != 0, 'Deposit not found.');

        uint time = block.timestamp; // now
        uint depositTime = time.sub(deposit.startAt); // now - deposit start time
        uint lastWithdrawTime = time.sub(withdraw.time); // now - last withdraw time

        require(lastWithdrawTime >= partExpiration && depositTime >= partExpiration, 'Can not withdraw yet.');

        uint amount = deposit.amount;

        uint interestAmount = amount.mul(interest).div(100);

        uint withdrawInterest;

        if (lastWithdrawTime == time) {
            withdrawInterest = interestAmount.mul(depositTime).div(fullExpiration);
        } else {
            withdrawInterest = interestAmount.mul(lastWithdrawTime).div(fullExpiration);
        }

        token.mint(msg.sender, withdrawInterest);

        withdraw.time = time;
        withdraw.totalAmount = withdraw.totalAmount.add(withdrawInterest);
        withdraws[msg.sender][_depositID] = withdraw;

        emit PartWithdraw(msg.sender, withdrawInterest, time);
    }

    function fullWithdraw(uint _depositID) public {

        Deposit memory deposit = deposits[msg.sender][_depositID];
        Withdraw memory withdraw = withdraws[msg.sender][_depositID];

        require(deposit.amount != 0, 'Deposit not found.');

        uint time = block.timestamp;
        uint depositTime = time.sub(deposit.startAt);

        require(depositTime >= fullExpiration, 'Can not withdraw yet.');

        uint withdrawAmount = withdraw.totalAmount;

        uint amount = deposit.amount;
        uint interestAmount = amount.mul(interest).div(100).sub(withdrawAmount);
        uint withdrawInterest = interestAmount.mul(depositTime).div(fullExpiration).sub(withdrawAmount);

        payable(msg.sender).transfer(amount);
        token.mint(msg.sender, withdrawInterest);

        emit FullWithdraw(msg.sender, amount, withdrawInterest, time);

        heroes[deposit.hero] = heroes[deposit.hero].sub(amount);

        emit HeroVoteMinus(msg.sender, deposit.hero, amount, time);

        deposit = Deposit(0, 0, '', 0);
        withdraw = Withdraw(0, 0);
    }

    function checkOwner(address _address) public view onlyOwners returns (address) {
        require(owners[_address] != address(0), 'This is not an owner.');
        return owners[_address];
    }

}
