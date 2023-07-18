const SweetToken = artifacts.require('SweetToken');
const Vote = artifacts.require('Vote');

const {
  BN,           // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time
} = require('@openzeppelin/test-helpers');


const hero1 = 'human';
const hero2 = 'bot';
const amount = 300;
const votesCount = 100;

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract('Vote', function (accounts) {

  it('should put 100 votes for both heroes at start', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const hero1Votes = await vote.heroes.call(hero1);
    const hero2Votes = await vote.heroes.call(hero2);

    assert.equal(hero1Votes, votesCount, 'hero1 should have 100 votes on start');
    assert.equal(hero2Votes, votesCount, 'hero2 should have 100 votes on start');
  });
  // it('first owner should be deployer', async function () {
  //   const token = await SweetToken.deployed();
  //   const vote = await Vote.deployed(token, hero1, hero2);
  //
  //   const ownerDeployer = vote.owners.call(0);
  //
  //   console.log(ownerDeployer);
  //   assert.equal(ownerDeployer, accounts[0], 'first owner should be deployer');
  // });
  it('should put votes and tokens to deposit', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];

    await vote.staking(hero1, {value: amount, from: holder});

    let deposit = await vote.deposits.call(holder, 1);
    let holderAmount = (deposit.amount).toNumber();

    const hero1Votes = (await vote.heroes.call(hero1)).toNumber();

    assert.equal(holderAmount, amount, 'deposit amount should be 300')
    assert.equal(hero1Votes, amount + 100, 'hero1 should has 100 + amount votes');
  });
  it('can not withdraw before 1 month', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];

    await vote.staking(hero1, {value: amount, from: holder});

    let deposit = await vote.deposits.call(holder, 1);
    let depositID = (deposit.id).toNumber();

    await expectRevert(
        vote.partWithdraw(depositID, {from: holder}),
        'Can not withdraw yet');
  });
  it('withdraw after 1 month', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];
    const partExpiration = await vote.partExpiration.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(partExpiration));

    await vote.partWithdraw(1, {from: holder});

    let withdraw = await vote.withdraws.call(holder, 1);
    let totalAmount = (withdraw.totalAmount).toNumber();
    let withdrawTime = (withdraw.time).toNumber();

    let balance = (await token.balanceOf(holder)).toNumber();
    let latestBlockTime = (await time.latest()).toNumber();

    assert.equal(totalAmount, balance, 'withdraw amount interest should be on account balance');
    assert.equal(withdrawTime, latestBlockTime, 'withdraw time should be latest block time');
  });
  it('withdraw after 1 year with interest', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];

    const fullExpiration = await vote.fullExpiration.call();
    const interest = await vote.interest.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(fullExpiration));

    await vote.fullWithdraw(1, {from: holder});

    let withdraw = await vote.withdraws.call(holder, 2);
    let totalAmount = (withdraw.totalAmount).toNumber();

    let balance = (await token.balanceOf(holder)).toNumber();
    let fullInterest = amount * interest / 100;

    assert.equal(totalAmount, 0, 'withdraw of this deposit should be zero');
    assert.equal(fullInterest, balance, 'balance should be interest');
  });
  it('withdraw after 5 years with interest', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[2];
    const fullExpiration = await vote.fullExpiration.call();
    const interest = await vote.interest.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(fullExpiration * 5));

    await vote.fullWithdraw(1, {from: holder});

    let withdraw = await vote.withdraws.call(holder, 1);
    let totalAmount = (withdraw.totalAmount).toNumber();

    let balance = (await token.balanceOf(holder)).toNumber();
    let fullInterest = amount * interest / 100 * 5;

    assert.equal(totalAmount, 0, 'withdraw should be zero');
    assert.equal(fullInterest, balance, 'balance should be interest mul 5');
  });
  it('withdraw no deposit', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[3];
    const partExpiration = await vote.partExpiration.call();

    await time.increase(time.duration.seconds(partExpiration));

    await expectRevert(
        vote.partWithdraw(1, {from: holder}),
        'Deposit not found.');
  });
});
