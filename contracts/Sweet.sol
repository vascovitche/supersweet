// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Sweet is ERC20 {

    using SafeMath for uint;

    uint private startUpCapital = 1e27;
    mapping(string => uint) public heroes; // hero name => votes

    uint8 public interest = 10;
    uint public fullExpiration = 60 * 60 * 24 * 365;
    uint public partExpiration = 60 * 60 * 24 * 30;

    struct Deposit {
        uint id;
        uint amount;
        string hero;
        uint startAt;
    }

    mapping(address => mapping(uint => Deposit)) private deposits;
    mapping(address => uint) public depositsCount;

    struct Withdraw {
        uint time;
        uint totalAmount;
    }

    mapping(address => mapping(uint => Withdraw)) private withdraws;

    event Staking(address indexed user, uint amount, string hero, uint startAt);
    event PartWithdraw(address indexed user, uint interest, uint time);
    event FullWithdraw(address indexed user, uint amount, uint interest, uint time);
    event HeroVotePlus(address indexed user, string hero, uint amount, uint time);
    event HeroVoteMinus(address indexed user, string hero, uint amount, uint time);

    constructor(string memory _hero1, string memory _hero2) payable ERC20('Sweet Token', 'SWT') {
        heroes[_hero1] = 100;
        heroes[_hero2] = 100;

        _mint(msg.sender, startUpCapital);
    }

    /**
     *
     *
     *
     *
     *
     *
     *
     *
     *
     * staking
     */

    function staking(uint _amount, string memory _hero) public payable {
        require(_amount > 0, 'Error, amount must be greater than 0');
        require(heroes[_hero] > 0, 'Error, hero not found');
        require(balanceOf(msg.sender) >= _amount, 'Error, not enough tokens');

        _burn(msg.sender, _amount);
        emit Staking(msg.sender, _amount, _hero, block.timestamp);

        uint depositId = addDepositsCount();
        addNewDeposit(depositId, _amount, _hero);
        increaseHeroVote(_hero, _amount);
        emit HeroVotePlus(msg.sender, _hero, _amount, block.timestamp);
    }

    function addDepositsCount() private returns (uint) {
        depositsCount[msg.sender] = depositsCount[msg.sender].add(1);

        return depositsCount[msg.sender];
    }

    function addNewDeposit(uint _depositId, uint _amount, string memory _hero) private {
        deposits[msg.sender][_depositId] = Deposit(_depositId, _amount, _hero, block.timestamp);
    }

    function increaseHeroVote(string memory _hero, uint _amount) private {
        heroes[_hero] = heroes[_hero].add(_amount);
    }

    function decreaseHeroVote(string memory _hero, uint _amount) private {
        heroes[_hero] = heroes[_hero].sub(_amount);
    }

    /**
     *
     *
     *
     *
     *
     *
     *
     *
     *
     * get deposits
     */

    function getHolderDeposits(address _holder) public view returns (Deposit[] memory) {
        uint depositCount = depositsCount[_holder];

        Deposit[] memory holderDeposits = new Deposit[](depositCount.add(1));

        for (uint i = 1; i <= depositCount; i++) {
            Deposit memory data = deposits[_holder][i];
            holderDeposits[i] = data;
        }

        return holderDeposits;
    }

    /**
     *
     *
     *
     *
     *
     *
     *
     *
     *
     * withdraws
     */

    function partWithdraw(uint _depositId) public payable {
        require(isDepositExists(_depositId), 'Deposit not found.');
        require(lastWithdrawTime(_depositId) >= partExpiration && depositTime(_depositId) >= partExpiration, 'Can not withdraw yet.');

        uint withdrawInterest = calculatePartWithdrawInterest(_depositId);
        _mint(msg.sender, withdrawInterest);
        updateWithdraw(_depositId, withdrawInterest);

        emit PartWithdraw(msg.sender, withdrawInterest, block.timestamp);
    }

    function fullWithdraw(uint _depositId) public payable {
        require(isDepositExists(_depositId), 'Deposit not found.');
        require(depositTime(_depositId) >= fullExpiration, 'Can not withdraw yet.');

        Deposit memory deposit = deposits[msg.sender][_depositId];
        uint withdrawInterest = calculateFullWithdrawInterest(_depositId);
        uint withdrawTotal = deposit.amount.add(withdrawInterest);
        _mint(msg.sender, withdrawTotal);
        emit FullWithdraw(msg.sender, deposit.amount, withdrawInterest, block.timestamp);

        decreaseHeroVote(deposit.hero, deposit.amount);
        emit HeroVoteMinus(msg.sender, deposit.hero, deposit.amount, block.timestamp);

        resetDeposit(_depositId);

    }

    /**
     *
     *
     *
     *
     *
     *
     *
     *
     *
     * helpers
     */

    function isDepositExists(uint _depositId) private view returns (bool) {
        return deposits[msg.sender][_depositId].amount != 0;
    }

    function depositTime(uint _depositId) private view returns (uint) {
        return block.timestamp.sub(deposits[msg.sender][_depositId].startAt);
    }

    function lastWithdrawTime(uint _depositId) private view returns (uint) {
        return block.timestamp.sub(withdraws[msg.sender][_depositId].time);
    }

    function calculatePartWithdrawInterest(uint _depositId) private view returns (uint) {
        uint amount = deposits[msg.sender][_depositId].amount;
        uint interestAmount = calculateInterestAmount(amount);
        uint withdrawInterest;

        if (lastWithdrawTime(_depositId) == block.timestamp) {
            withdrawInterest = interestAmount.mul(depositTime(_depositId)).div(fullExpiration);
        } else {
            withdrawInterest = interestAmount.mul(lastWithdrawTime(_depositId)).div(fullExpiration);
        }

        return withdrawInterest;
    }

    function calculateFullWithdrawInterest(uint _depositId) private view returns (uint) {
        uint amount = deposits[msg.sender][_depositId].amount;
        uint interestAmount = calculateInterestAmount(amount);
        uint withdrawInterest = interestAmount.mul(depositTime(_depositId)).div(fullExpiration).sub(withdraws[msg.sender][_depositId].totalAmount);

        return withdrawInterest;
    }

    function calculateInterestAmount(uint _amount) private view returns (uint) {
        return _amount.mul(interest).div(100);
    }

    function updateWithdraw(uint _depositId, uint _withdrawInterest) private {
        uint totalAmount = withdraws[msg.sender][_depositId].totalAmount.add(_withdrawInterest);
        withdraws[msg.sender][_depositId] = Withdraw(block.timestamp, totalAmount);
    }

    function resetDeposit(uint _depositId) private {
        deposits[msg.sender][_depositId] = Deposit(0, 0, '', 0);
        withdraws[msg.sender][_depositId] = Withdraw(0, 0);
    }

}
