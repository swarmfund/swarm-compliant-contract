const {BN, constants, expectEvent, shouldFail, inLogs} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const helpers = require('./helpers');

const SRC20Registry = artifacts.require('SRC20RegistryMock');
const SRC20Factory = artifacts.require('SRC20Factory');
const SRC20 = artifacts.require('SRC20Mock');
const SwarmTokenMock = artifacts.require('SwarmTokenMock');
const SRC20Roles = artifacts.require('SRC20Roles');
const Featured = artifacts.require('FeaturedMock');
const AssetRegistry = artifacts.require('AssetRegistry');
const GetRateMinter = artifacts.require('GetRateMinter');
const SWMPriceOracle = artifacts.require('SWMPriceOracle');

contract('GetRateMinter', function ([_, owner, account0, account1, account2, account3]) {
  const kyaHash = crypto.createHash('sha256').update(constants.ZERO_ADDRESS).digest();
  const kyaUrl = 'https://www.mvpworkshop.co';
  const swmTotalSupply = new BN(1000000).mul(new BN(10).pow(new BN(36)));
  const srcTotalSupply = new BN(0);
  const features = 0x00;
  const SRC20_DECIMALS = new BN(8); // test with decimals diff
  const SWM_DECIMALS = new BN(18);
  const maxSrcTotalSupply = new BN(10000000000).mul(new BN(10).pow(SRC20_DECIMALS));
  const SWM_PRICE_USD_NUMERATOR = 5
  const SWM_PRICE_USD_DENOMINATOR = 100
  const NAV = 1000;

  beforeEach(async function () {
    this.swarmTokenMock = await SwarmTokenMock.new(account0, swmTotalSupply, {from: owner});
    this.registry = await SRC20Registry.new(this.swarmTokenMock.address, {from: owner});
    this.factory = await SRC20Factory.new(this.registry.address, {from: owner});
    await this.registry.addFactory(this.factory.address, {from: owner});

    this.sWMPriceOracle = await SWMPriceOracle.new(SWM_PRICE_USD_NUMERATOR, SWM_PRICE_USD_DENOMINATOR, {from: owner});
    this.assetRegistry = await AssetRegistry.new(this.factory.address, {from: owner});

    this.GetRateMinter = await GetRateMinter.new(this.registry.address, this.assetRegistry.address, this.sWMPriceOracle.address, {from: owner});
    this.registry.addMinter(this.GetRateMinter.address, {from: owner});

    this.roles = await SRC20Roles.new(owner, this.registry.address, {from: owner});
    this.feature = await Featured.new(owner, features, {from: owner});

    const tx = await this.factory.create(
        'SRC20 token',
        'SRC',
        SRC20_DECIMALS,
        maxSrcTotalSupply,
        kyaHash,
        kyaUrl,
        NAV,
        [
          account0,
          constants.ZERO_ADDRESS,
          constants.ZERO_ADDRESS,
          this.roles.address,
          this.feature.address,
          this.assetRegistry.address,
          this.GetRateMinter.address
        ],
      {from: owner}
    );

    this.unregisteredToken = await SRC20.new(
        'SRC20 token',
        'SRC',
        SRC20_DECIMALS,
        maxSrcTotalSupply,
        [
          account0,
          constants.ZERO_ADDRESS,
          constants.ZERO_ADDRESS,
          this.roles.address,
          this.feature.address,
          this.assetRegistry.address
        ],
        srcTotalSupply,
      {from: owner}
    );

    this.tokenAddress = tx.receipt.logs.find(log => {
      return log.event === 'SRC20Created';
    }).args.token;

    this.token = await SRC20.at(this.tokenAddress);
  });

  describe('Calculating the SWM stake amount', function () {

    it('should return correct stake for various inputs', async function () {

      const SWMPRICENUMERATOR = new BN(SWM_PRICE_USD_NUMERATOR);
      const SWMPRICEDENOMINATOR = new BN(SWM_PRICE_USD_DENOMINATOR);


      let NAV   = new BN(250000);
      let expected = new BN(2500*100/5).mul((new BN(10)).pow(new BN(18)));
      let result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


          NAV   = new BN(750000);
      let fnum  = new BN(5)
      let fden  = new BN(1000);
          expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
          result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(1500000);
      fnum  = new BN(45)
      fden  = new BN(10000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(7300000);
      fnum  = new BN(4)
      fden  = new BN(1000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(23000000);
      fnum  = new BN(25)
      fden  = new BN(10000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(88500000);
      fnum  = new BN(2)
      fden  = new BN(1000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);

      
      NAV   = new BN(143700000);
      fnum  = new BN(15)
      fden  = new BN(10000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(239000000);
      fnum  = new BN(1)
      fden  = new BN(1000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);


      NAV   = new BN(1000000000);
      fnum  = new BN(1)
      fden  = new BN(1000);
      expected = NAV.mul(fnum).div(fden).mul(SWMPRICEDENOMINATOR).div(SWMPRICENUMERATOR).mul((new BN(10)).pow(new BN(18)));
      result = await this.GetRateMinter.calcStake(NAV, {from: account1});
      console.log('      For NAV: ' + NAV.toLocaleString() +
                  ', Result: ' + result.toLocaleString() +
                  ', Expected: ' + expected.toLocaleString());
      await assert.equal((result).eq(expected), true);

    });

  });

  describe('Staking and minting the supply', function () {

    it('should not allow staking and minting to be initiated by anyone but the SRC20 Token owner', async function () {
      const value = new BN(100);

      await shouldFail.reverting.withMessage(this.GetRateMinter.stakeAndMint(this.token.address, value, {from: account1}),
        'caller not token owner.');

    });

    it('should mint the correct SRC20 supply based on the NAV', async function () {

      const NAV = new BN(1000);
      const src20Value = new BN(200);
      const weiSRC20Value = src20Value.mul(new BN(10).pow(SRC20_DECIMALS));

      const startingErc20balance = await this.swarmTokenMock.balanceOf(account0);
      const startingErc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      const startingSrc20balance = await this.token.balanceOf(account0);
      const startingStake = await this.registry.getStake(this.token.address);

      const calcResult = await this.GetRateMinter.calcStake(NAV, {from: account1});
      await this.swarmTokenMock.approve(this.registry.address, calcResult, {from: account0});
      await this.GetRateMinter.stakeAndMint(this.token.address, weiSRC20Value, {from: account0});

      // That the SWM tokens have been sutracted from the staking account
      const erc20balance = await this.swarmTokenMock.balanceOf(account0);
      assert.equal((startingErc20balance.sub(calcResult)).eq(erc20balance), true);

      // That the SWM tokens have been added to the registry contract
      const erc20contractBalance = await this.swarmTokenMock.balanceOf(this.registry.address);
      assert.equal(startingErc20contractBalance.add(calcResult).eq(erc20contractBalance), true);

      // That the correct amount of SRC20 tokens has been minted
      const src20balance = await this.token.balanceOf(account0);
      assert.equal((startingSrc20balance.add(weiSRC20Value)).eq(src20balance), true);

      // That the registry has registered the SWM stake change
      const stake = await this.registry.getStake(this.token.address);
      assert.equal(startingStake.add(calcResult).eq(stake), true)
    });
  });
});
