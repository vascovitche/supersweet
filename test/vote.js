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
  it('should put votes and tokens to deposit', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];

    await vote.staking(hero1, {value: amount, from: holder});

    let depositsCount = await vote.depositsCount.call(holder);
    let deposit = await vote.deposits.call(holder, depositsCount);
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

    let depositsCount = await vote.depositsCount.call(holder);
    let deposit = await vote.deposits.call(holder, depositsCount);
    let depositID = (deposit.id).toNumber();

    await expectRevert(
        vote.partWithdraw(depositID, {from: holder}),
        'Can not withdraw yet');
  });
  it('can not withdraw full before 1 year', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const fullExpiration = await vote.fullExpiration.call();

    const holder = accounts[1];

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(fullExpiration - 1));

    let depositsCount = await vote.depositsCount.call(holder);
    let deposit = await vote.deposits.call(holder, depositsCount);
    let depositID = (deposit.id).toNumber();

    await expectRevert(
        vote.fullWithdraw(depositID, {from: holder}),
        'Can not withdraw yet');
  });
  it('withdraw after 1 month', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[1];
    const partExpiration = await vote.partExpiration.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(partExpiration));

    let depositID = await vote.depositsCount.call(holder);

    await vote.partWithdraw(depositID, {from: holder});

    let withdraw = await vote.withdraws.call(holder, depositID);
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

    const holder = accounts[4];

    const fullExpiration = await vote.fullExpiration.call();
    const interest = (await vote.interest.call()).toNumber();

    await vote.staking(hero1, {value: amount, from: holder});

    let startHeroVotes = (await vote.heroes.call(hero1)).toNumber();

    await time.increase(time.duration.seconds(fullExpiration));

    let depositID = (await vote.depositsCount.call(holder)).toNumber();
    await vote.fullWithdraw(depositID, {from: holder});

    let withdraw = await vote.withdraws.call(holder, depositID);
    let totalAmount = (withdraw.totalAmount).toNumber();

    let balance = (await token.balanceOf(holder)).toNumber();
    let fullInterest = amount * interest / 100;

    let afterWithdrawHeroVotes = (await vote.heroes.call(hero1)).toNumber();

    assert.equal(totalAmount, 0, 'withdraw of this deposit should be zero');
    assert.equal(fullInterest, balance, 'balance should be interest');
    assert.equal(startHeroVotes - amount, afterWithdrawHeroVotes, 'hero votes should change after full withdraw');
  });
  it('withdraw after 5 years with interest', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[2];
    const fullExpiration = await vote.fullExpiration.call();
    const interest = await vote.interest.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(fullExpiration * 5));

    let depositID = await vote.depositsCount.call(holder);
    await vote.fullWithdraw(depositID, {from: holder});

    let withdraw = await vote.withdraws.call(holder, depositID);
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
  it('part withdraw once again', async function () {
    const token = await SweetToken.deployed();
    const vote = await Vote.deployed(token, hero1, hero2);

    const holder = accounts[5];
    const partExpiration = await vote.partExpiration.call();

    await vote.staking(hero1, {value: amount, from: holder});

    await time.increase(time.duration.seconds(partExpiration));

    let depositID = await vote.depositsCount.call(holder);
    await vote.partWithdraw(depositID, {from: holder});

    let withdraw = await vote.withdraws.call(holder, depositID);
    let totalAmount = (withdraw.totalAmount).toNumber();

    let balance = (await token.balanceOf(holder)).toNumber();

    assert.equal(totalAmount, balance, 'withdraw amount interest should be on account balance');

    let currentTime = await time.increase(time.duration.seconds(partExpiration * 3));

    console.log(currentTime);

    await vote.partWithdraw(depositID, {from: holder});

    let totalAmountAfterSecondWithdraw = (withdraw.totalAmount).toNumber();

    let balanceAfterSecondWithdraw = (await token.balanceOf(holder)).toNumber();

    console.log(totalAmountAfterSecondWithdraw, balanceAfterSecondWithdraw);


    assert.equal(totalAmountAfterSecondWithdraw, balanceAfterSecondWithdraw, 'withdraw amount interest should be on account balance');
    assert.equal(totalAmountAfterSecondWithdraw, totalAmount * 3, 'withdraw amount interest should be on account balance');
    assert.equal(balanceAfterSecondWithdraw, balance * 3, 'withdraw amount interest should be on account balance');
  });
});
