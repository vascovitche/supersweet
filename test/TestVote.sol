// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SweetToken.sol";
import "../contracts/Vote.sol";

contract TestVote {

    function testInitialHeroes() public {
        SweetToken sweetToken = new SweetToken();
        Vote vote = new Vote(sweetToken, 'human', 'bot');

        uint startVotes = 100;

        Assert.equal(vote.heroes('human'), startVotes, 'First hero should be human. It must has to 100 votes');
        Assert.equal(vote.heroes('bot'), startVotes, 'Second hero should be human. It must has to 100 votes');
    }

//    function testDefaultOwner() public {
//        SweetToken sweetToken = new SweetToken();
//        Vote vote = new Vote(sweetToken, 'human', 'bot');
//
//        Assert.equal(vote.owners(msg.sender), msg.sender, 'Owner should be the deployer');
//    }

}
