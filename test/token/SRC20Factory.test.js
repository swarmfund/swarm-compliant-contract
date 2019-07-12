const {BN, constants, expectEvent, shouldFail, inLogs} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const helpers = require('./helpers');

const SRC20Registry = artifacts.require('SRC20RegistryMock');
const SRC20Factory = artifacts.require('SRC20Factory');
const SRC20 = artifacts.require('SRC20');
const SwarmTokenMock = artifacts.require('SwarmTokenMock');

contract('SRC20Factory', function ([_, owner, account0, account1]) {
  const kyaHash = crypto.createHash('sha256').update(constants.ZERO_ADDRESS).digest();
  const kyaUrl = 'https://www.mvpworkshop.co';
  const swmTotalSupply = new BN(1000000).mul(new BN(10).pow(new BN(36)));
  const srcTotalSupply = new BN(10000);
  const features = 0x00;
  const SRC20_DECIMALS = new BN(8); // test with decimals diff
  const SWM_DECIMALS = new BN(18);

  beforeEach(async function () {
    this.swarmTokenMock = await SwarmTokenMock.new(account0, swmTotalSupply, {from: owner});
    this.registry = await SRC20Registry.new(this.swarmTokenMock.address, {from: owner});
    this.factory = await SRC20Factory.new(this.registry.address, {from: owner});

    await this.registry.addFactory(this.factory.address, {from: owner});

    const tx = await this.factory.create(
      account0,
      'SRC20 token',
      'SRC',
      SRC20_DECIMALS,
      kyaHash,
      kyaUrl,
      constants.ZERO_ADDRESS,
      features,
      srcTotalSupply,
      {from: owner}
    );

    this.unregisteredToken = await SRC20.new(
      account0,
      'SRC20 token',
      'SRC',
      new BN(18),
      kyaHash,
      kyaUrl,
      constants.ZERO_ADDRESS,
      features,
      srcTotalSupply,
      {from: owner}
    );

    this.tokenAddress = tx.receipt.logs.find(log => {
      return log.event === 'SRC20Created';
    }).args.token;

    this.token = await SRC20.at(this.tokenAddress);
  });

  describe('Keeping SRC20 tokens in registry', function () {
    it('should allow only factory to register tokens', async function () {
      await shouldFail.reverting.withMessage(this.registry.put(account0, account1, {from: owner}),
        "factory not registered"
      );
    });

    it('should contain only registered tokens', async function () {
      assert.equal(await this.registry.contains(this.tokenAddress), true);
      assert.equal(await this.registry.contains(account1), false);
    });

    it('should set owner of deployed SRC20 contract correctly', async function () {
      assert.equal(await this.token.owner.call() === account0, true);
    });

    it('should allow removal of token from registry to owner', async function () {
      ({logs: this.logs} = await this.registry.remove(this.tokenAddress, {from: owner}));
      expectEvent.inLogs(this.logs, 'SRC20Removed', {
        token: this.tokenAddress
      });

      assert(await this.registry.contains(this.tokenAddress) === false, true);
    });
  });

  describe('Managing registered SRC20 tokens', function () {
    it('should not allow any management operations to non-manager account', async function () {
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.token.mint(account0, value, {from: owner}),
        'Caller not manager');

      await shouldFail.reverting.withMessage(this.token.burn(account0, value, {from: owner}),
        'Caller not manager');
    });

    it('should not allow any management operations for unregistered SRC20 token', async function () {
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.registry.mintSupply(this.unregisteredToken.address, account0, value, value, {from: owner}),
        'SRC20 token contract not registered');

      await shouldFail.reverting.withMessage(this.registry.renounceManagement(this.unregisteredToken.address, {from: owner}),
        'SRC20 token contract not registered');
    });

    it('should not allow any token owner operations to non token owner caller', async function () {
      const tokenOwner = account0;
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.registry.incStake(this.tokenAddress, tokenOwner, value, {from: account1}),
        'caller not token owner');

      await shouldFail.reverting.withMessage(this.registry.decStake(this.tokenAddress, tokenOwner, value, {from: account1}),
        'caller not token owner');
    });

    it('should mint requested SRC20 supply correctly', async function () {
      const swmValue = new BN(100);
      const src20Value = new BN(200);
      const weiSWMValue = swmValue.mul(new BN(10).pow(SWM_DECIMALS));
      const weiSRC20Value = src20Value.mul(new BN(10).pow(SRC20_DECIMALS));

      const startingErc20balance = await this.swarmTokenMock.balanceOf(account0);
      const startingErc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      await this.swarmTokenMock.approve(this.registry.address, weiSWMValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSWMValue, weiSRC20Value, {from: owner});

      const erc20balance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal((startingErc20balance.sub(weiSWMValue)).eq(erc20balance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingErc20contractBalance.add(weiSWMValue).eq(erc20contractBalance), true);

      const scr20balance = await this.token.balanceOf(account0);
      assert.equal((startingScr20balance.add(weiSRC20Value)).eq(scr20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.add(weiSWMValue).eq(stake), true)
    });

    it('should increase SRC20 supply with new SWM stake correctly', async function () {
      const swmValue = new BN(100);
      const src20Value = new BN(200);
      const weiSWMValue = swmValue.mul(new BN(10).pow(SWM_DECIMALS));
      const weiSRC20Value = src20Value.mul(new BN(10).pow(SRC20_DECIMALS));

      await this.swarmTokenMock.approve(this.registry.address, weiSWMValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSWMValue, weiSRC20Value, {from: owner});

      const startingErc20balance = await this.swarmTokenMock.balanceOf(account0);
      const startingErc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);


      await this.swarmTokenMock.approve(this.registry.address, weiSWMValue, {from: account0});
      await this.registry.incStake(this.token.address, account0, weiSWMValue, {from: account0});

      const supply = await this.token.totalSupply();
      const incStakeSrcValue = helpers.utils.calcTokens(weiSRC20Value, weiSWMValue, weiSWMValue);
      assert.equal(srcTotalSupply.add(weiSRC20Value).add(incStakeSrcValue).eq(supply), true);

      const erc20balance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal((startingErc20balance.sub(weiSWMValue)).eq(erc20balance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingErc20contractBalance.add(weiSWMValue).eq(erc20contractBalance), true);

      const src20balance = await this.token.balanceOf(account0);
      assert.equal((startingScr20balance.add(weiSRC20Value)).eq(src20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.add(weiSWMValue).eq(stake), true)
    });

    it('should decrease SRC20 supply for part of SWM stake correctly', async function () {
      const weiSrcValue = new BN(200).mul(new BN(10).pow(SRC20_DECIMALS));
      const weiSwmValue = new BN(100).mul(new BN(10).pow(SWM_DECIMALS));
      const weiSwmValueStake = new BN(50).mul(new BN(10).pow(SWM_DECIMALS));

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, weiSrcValue, {from: owner});

      const startingSwmBalance = await this.swarmTokenMock.balanceOf(account0);
      const startingSwmContractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      await this.registry.decStake(this.token.address, account0, weiSwmValueStake, {from: account0});

      const supply = await this.token.totalSupply();
      const unstakedSrcValue = helpers.utils.calcTokens(weiSrcValue, weiSwmValue, weiSwmValueStake);
      assert.equal(srcTotalSupply.add(weiSrcValue).sub(unstakedSrcValue).eq(supply), true);

      const swmbalance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal(startingSwmBalance.add(weiSwmValueStake).eq(swmbalance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingSwmContractBalance.sub(weiSwmValueStake).eq(erc20contractBalance), true);

      const src20balance = await this.token.balanceOf(account0);
      assert.equal(startingScr20balance.sub(unstakedSrcValue).eq(src20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.sub(weiSwmValueStake).eq(stake), true)
    });

    it('should mint additional phase SRC20 supply correctly', async function () {
      const weiSrcValue = new BN(200).mul(new BN(10).pow(SRC20_DECIMALS));
      const weiSwmValue = new BN(100).mul(new BN(10).pow(SWM_DECIMALS));
      const weiSwmValueStake = new BN(50).mul(new BN(10).pow(SWM_DECIMALS));

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, weiSrcValue, {from: owner});

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValueStake, {from: account0});
      await this.registry.incStake(this.token.address, account0, weiSwmValueStake, {from: account0});

      const startingSwmBalance = await this.swarmTokenMock.balanceOf(account0);
      const startingSwmContractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValueStake, {from: account0});
      await this.registry.incStake(this.token.address, account0, weiSwmValueStake, {from: account0});

      const supply = await this.token.totalSupply();
      const stakedTokens = helpers.utils.calcTokens(weiSrcValue, weiSwmValue, weiSwmValueStake);
      assert.equal(srcTotalSupply.add(weiSrcValue).add(stakedTokens).add(stakedTokens).eq(supply), true);

      const swmBalance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal(startingSwmBalance.sub(weiSwmValueStake).eq(swmBalance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingSwmContractBalance.add(weiSwmValueStake).eq(erc20contractBalance), true);

      const src20balance = await this.token.balanceOf(account0);
      assert.equal(startingScr20balance.add(stakedTokens).eq(src20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.add(weiSwmValueStake).eq(stake), true)
    });

    it('should follow new rate stake increase', async function () {
      const two = new BN(2);

      const weiSrcValue = new BN(200).mul(new BN(10).pow(SRC20_DECIMALS));
      const newWeiSrcValue = weiSrcValue.mul(two);

      const weiSwmValue = new BN(100).mul(new BN(10).pow(SWM_DECIMALS));
      const weiSwmValueStake = new BN(50).mul(new BN(10).pow(SWM_DECIMALS));

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, weiSrcValue, {from: owner});

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, newWeiSrcValue, {from: owner});

      const startingSwmBalance = await this.swarmTokenMock.balanceOf(account0);
      const startingSwmContractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValueStake, {from: account0});
      await this.registry.incStake(this.token.address, account0, weiSwmValueStake, {from: account0});

      const supply = await this.token.totalSupply();
      const incSrcStakeValue = helpers.utils.calcTokens(newWeiSrcValue, weiSwmValue, weiSwmValueStake);
      assert.equal((srcTotalSupply.add(weiSrcValue).add(newWeiSrcValue).add(incSrcStakeValue)).eq(supply), true);

      const erc20balance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal(startingSwmBalance.sub(weiSwmValueStake).eq(erc20balance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingSwmContractBalance.add(weiSwmValueStake).eq(erc20contractBalance), true);

      const src20balance = await this.token.balanceOf(account0);
      assert.equal(startingScr20balance.add(incSrcStakeValue).eq(src20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.add(weiSwmValueStake).eq(stake), true);
    });
    //
    it('should follow new rate stake decrease', async function () {
      const weiSrcValue = new BN(200).mul(new BN(10).pow(SRC20_DECIMALS));
      const weiSwmValue = new BN(100).mul(new BN(10).pow(SWM_DECIMALS));
      const weiSwmValueStake = new BN(50).mul(new BN(10).pow(SWM_DECIMALS));

      const two = new BN(2);
      const newWeiSrcValue = weiSrcValue.mul(two);

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, weiSrcValue, {from: owner});

      await this.swarmTokenMock.approve(this.registry.address, weiSwmValue, {from: account0});
      await this.registry.mintSupply(this.token.address, account0, weiSwmValue, newWeiSrcValue, {from: owner});

      const startingSwmBalance = await this.swarmTokenMock.balanceOf(account0);
      const startingSwmContractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);

      const startingScr20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      await this.registry.decStake(this.token.address, account0, weiSwmValueStake, {from: account0});

      const supply = await this.token.totalSupply();
      const decSrcStakeValue = helpers.utils.calcTokens(newWeiSrcValue, weiSwmValue, weiSwmValueStake);
      assert.equal(srcTotalSupply.add(weiSrcValue).add(newWeiSrcValue).sub(decSrcStakeValue).eq(supply), true);

      const erc20balance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal(startingSwmBalance.add(weiSwmValueStake).eq(erc20balance), true);

      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingSwmContractBalance.sub(weiSwmValueStake).eq(erc20contractBalance), true);

      const src20balance = await this.token.balanceOf(account0);
      assert.equal(startingScr20balance.sub(decSrcStakeValue).eq(src20balance), true);

      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.sub(weiSwmValueStake).eq(stake), true);
    });

    it('should not allow any management operations to non-manager account', async function () {
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.token.mint(account0, value, {from: owner}),
        'Caller not manager');

      await shouldFail.reverting.withMessage(this.token.burn(account0, value, {from: owner}),
        'Caller not manager');
    });

    it('should not allow any management operations for unregistered SRC20 token', async function () {
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.registry.mintSupply(this.unregisteredToken.address, account0, value, value, {from: owner}),
        'SRC20 token contract not registered');

      await shouldFail.reverting.withMessage(this.registry.renounceManagement(this.unregisteredToken.address, {from: owner}),
        'SRC20 token contract not registered');
    });

    it('should not allow any token owner operations to non token owner caller', async function () {
      const tokenOwner = account0;
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.registry.incStake(this.tokenAddress, tokenOwner, value, {from: account1}),
        'caller not token owner');

      await shouldFail.reverting.withMessage(this.registry.decStake(this.tokenAddress, tokenOwner, value, {from: account1}),
        'caller not token owner');
    });

    it('should be able to transfer management to another manager contract', async function () {
      await this.registry.transferManagement(this.token.address, account0, {from: owner});

      const manager = await this.token.manager();
      assert.equal(account0 === manager, true);
    });
    it('should be able to renounce management', async function () {
      await this.registry.renounceManagement(this.token.address, {from: owner});

      const manager = await this.token.manager();
      assert.equal(manager === constants.ZERO_ADDRESS, true);
    });
  });
});
