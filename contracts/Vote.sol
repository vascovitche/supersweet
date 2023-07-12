// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Vote {

    address token;
    uint8 public interest = 10;
    uint public expiration = 30;
//    uint public expiration = 60 * 60 * 24 * 30;

    mapping(address => address) owners;
    mapping(string => uint) heroes; // hero name => votes

    mapping(address => mapping(uint256 => uint256)) public deposits; // address => [block.timestamp => msg.value]
    mapping(address => uint256) public depositsCount; // address => id(counted++);
    mapping(address => mapping(uint256 => uint256)) public depositIDTimes; // address => [id(counted++) => block.timestamp]

    modifier onlyOwners() {
        require(owners[msg.sender] != address(0), 'Only owners can set new admin.');
        _;
    }

    constructor(address _token, string memory _hero1, string memory _hero2) public {
        owners[msg.sender] = msg.sender;

        token = _token;
        heroes[_hero1] = 0;
        heroes[_hero2] = 0;
    }

    function setOwner(address _owner) public onlyOwners {
        owners[_owner] = _owner;
    }

    function deposit(string _heroName) public payable {
        require(heroes[_heroName] != 0, 'Hero not found.');

        uint count = depositsCount[msg.sender] + 1;
        uint time = block.timestamp;

        deposits[msg.sender][time] = msg.value;
        depositsCount[msg.sender] = count;
        depositIDTimes[msg.sender][count] = time;

        heroes[_heroName] = heroes[_heroName] + msg.value;
    }

    function withdraw(address _holder, uint256 _depositStart) public payable {
        require(deposits[_holder][_depositStart] != 0, 'Deposit not found.');
        require(block.timestamp - _depositStart >= expiration, 'Deposit is not expired.');
        require(msg.sender == _holder, 'Only owner can withdraw.');

        uint256 amount = deposits[_holder][_depositStart];
        uint256 interestAmount = amount * interest / 100;
        uint256 totalAmount = amount + interestAmount;

        msg.sender.transfer(totalAmount);

        deposits[_holder][_depositStart] = 0;
    }

}
