const Sweet = artifacts.require('Sweet');

const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  time
} = require('@openzeppelin/test-helpers');

const hero1 = 'human';
const hero2 = 'bot';
const amount = 300;
const startVotesCount = 100;

let holder;
let deployer;

contract('Sweet', function (accounts) {

  beforeEach(async function () {
    sweet = await Sweet.new(hero1, hero2);
    deployer = accounts[0];
    holder = accounts[1];
  });

  it ('should be 1e27 tokens in total supply', async function () {
    let totalTokens = await sweet.totalSupply();
    let deployerBalance = await sweet.balanceOf(deployer);

    assert.equal(totalTokens, 1e27, 'total supply should be 1e27');
    assert.equal(deployerBalance, 1e27, 'deployer should have 1e27 tokens');
  });

  it ('should be 100 votes for each heroes at start', async function () {
    const hero1Votes = await sweet.heroes.call(hero1);
    const hero2Votes = await sweet.heroes.call(hero2);

    assert.equal(hero1Votes, startVotesCount, 'hero1 should have 100 votes at start');
    assert.equal(hero2Votes, startVotesCount, 'hero2 should have 100 votes at start');
    assert.equal(hero1Votes, hero1Votes, 'hero1 should have 100 votes same as hero2');
  });

  it ('sell tokens to holder', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);

    let holderBalance = await sweet.balanceOf(holder);
    let deployerBalance = await sweet.balanceOf(deployer);

    assert.equal(holderBalance, amount, 'holder should have 300 tokens');
    assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
  });

  it('staking should be successfully', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);
    await sweet.staking(amount, hero1, {from: holder});

    let holderBalance = await sweet.balanceOf(holder);
    let deployerBalance = await sweet.balanceOf(deployer);

    let hero1Votes = (await sweet.heroes.call(hero1)).toNumber();

    assert.equal(holderBalance, 0, 'holder should have 0 tokens');
    assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
    assert.equal(hero1Votes, startVotesCount + amount, 'hero1 should have + 300 votes');
  });

  it('part withdraw should be successfully', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);
    await sweet.staking(amount, hero1, {from: holder});

    const partExpiration = await sweet.partExpiration.call();
    const fullExpiration = await sweet.fullExpiration.call();
    await time.increase(time.duration.seconds(partExpiration));
    let depositId = await sweet.depositsCount.call(holder);

    await sweet.partWithdraw(depositId, {from: holder});

    let interest = (await sweet.interest.call()).toNumber();
    let withdraw = ((amount * interest / 100) * partExpiration / fullExpiration).toFixed();

    let holderBalance = await sweet.balanceOf(holder);
    let deployerBalance = await sweet.balanceOf(deployer);

    assert.equal(holderBalance, withdraw, 'holder balance should be equal withdraw');
    assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
  });

  it('can not withdraw before 1 month', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);
    await sweet.staking(amount, hero1, {from: holder});

    const partExpiration = await sweet.partExpiration.call();
    await time.increase(time.duration.seconds(partExpiration - 1));
    let depositId = await sweet.depositsCount.call(holder);

    await expectRevert(
        sweet.partWithdraw(depositId, {from: holder}),
'Can not withdraw yet');
  });

  it('full withdraw should be successfully', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);
    await sweet.staking(amount, hero1, {from: holder});

    const fullExpiration = await sweet.fullExpiration.call();
    await time.increase(time.duration.seconds(fullExpiration));
    let depositId = await sweet.depositsCount.call(holder);

    await sweet.fullWithdraw(depositId, {from: holder});

    let interest = (await sweet.interest.call()).toNumber();
    let withdraw = amount * interest / 100;

    let holderBalance = await sweet.balanceOf(holder);
    let deployerBalance = await sweet.balanceOf(deployer);

    assert.equal(holderBalance, withdraw + amount, 'holder balance should be equal withdraw');
    assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
  });

    it('full withdraw after 5 years', async function () {
        await sweet.approve(deployer, amount);
        await sweet.transferFrom(deployer, holder, amount);
        await sweet.staking(amount, hero1, {from: holder});

        const fullExpiration = await sweet.fullExpiration.call();
        await time.increase(time.duration.seconds(fullExpiration * 5));
        let depositId = await sweet.depositsCount.call(holder);

        await sweet.fullWithdraw(depositId, {from: holder});

        let interest = (await sweet.interest.call()).toNumber();
        let withdraw = (amount * interest / 100) * 5;

        let holderBalance = await sweet.balanceOf(holder);
        let deployerBalance = await sweet.balanceOf(deployer);

        assert.equal(holderBalance, withdraw + amount, 'holder balance should be equal withdraw');
        assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
    });

  it('can not withdraw before 1 year', async function () {
    await sweet.approve(deployer, amount);
    await sweet.transferFrom(deployer, holder, amount);
    await sweet.staking(amount, hero1, {from: holder});

    const fullExpiration = await sweet.fullExpiration.call();
    await time.increase(time.duration.seconds(fullExpiration - 1));
    let depositId = await sweet.depositsCount.call(holder);

    await expectRevert(
        sweet.fullWithdraw(depositId, {from: holder}),
        'Can not withdraw yet');
    });

    it('can not withdraw no deposit', async function () {
        await sweet.approve(deployer, amount);
        await sweet.transferFrom(deployer, holder, amount);

        const fullExpiration = await sweet.fullExpiration.call();
        const partExpiration = await sweet.partExpiration.call();

        await time.increase(time.duration.seconds(partExpiration));
        let depositId = await sweet.depositsCount.call(holder);

        await expectRevert(
            sweet.partWithdraw(depositId, {from: holder}),
            'Deposit not found');

        await time.increase(time.duration.seconds(fullExpiration));

        await expectRevert(
            sweet.fullWithdraw(depositId, {from: holder}),
            'Deposit not found');
    });

    it('part withdraw, then full withdraw', async function () {
        await sweet.approve(deployer, amount);
        await sweet.transferFrom(deployer, holder, amount);
        await sweet.staking(amount, hero1, {from: holder});

        const fullExpiration = await sweet.fullExpiration.call();
        const partExpiration = await sweet.partExpiration.call();

        await time.increase(time.duration.seconds(partExpiration));
        let depositId = await sweet.depositsCount.call(holder);
        await sweet.partWithdraw(depositId, {from: holder});

        let holderBalance = await sweet.balanceOf(holder);

        let interest = (await sweet.interest.call()).toNumber();
        let withdraw = ((amount * interest / 100) * partExpiration / fullExpiration).toFixed();
        assert.equal(holderBalance, withdraw, 'holder balance should be equal withdraw');

        await time.increase(time.duration.seconds(fullExpiration - partExpiration));
        await sweet.fullWithdraw(depositId, {from: holder});


        withdraw = (amount * interest / 100);

        holderBalance = await sweet.balanceOf(holder);
        let deployerBalance = await sweet.balanceOf(deployer);

        assert.equal(holderBalance, withdraw + amount, 'holder balance should be equal withdraw');
        assert.equal(deployerBalance, 1e27 - amount, 'deployer should have 1e27 - 300 tokens');
    });

});
