const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const Erc20Token = artifacts.require('SwarmTokenMock');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor, src20]) {
    const label = "mvpworkshop.co";
    const tokenAmount = new BN(1000);
    const startDate = new BN(moment().unix());
    const endDate = new BN(moment().unix() + 100);
    const softCap = new BN(100);
    const hardCap = new BN(1000);
    let baseCurrency;

    const ercTotalSupply = new BN(10000);

    const tokenPrice = new BN(10);
    const totalTokenAmount = new BN(100000);

    const amount = new BN(10);
    const minAmount = new BN(5);
    const maxAmount = new BN(100);

    beforeEach(async function () {
        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        baseCurrency = this.acceptedToken.address;

        // @TODO should register erc20 tokens to some kind of accepted currency registry
    });

    describe('Handling if fundraising is set up correctly', function () {
        it('should have all needed variables', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            const fundLabel = await swarmPoweredFundraiseMock.label();
            const fundSrc20 = await swarmPoweredFundraiseMock.src20();
            const fundTokenAmount = await swarmPoweredFundraiseMock.tokenAmount();
            const fundStartDate = await swarmPoweredFundraiseMock.startDate();
            const fundEndDate = await swarmPoweredFundraiseMock.endDate();
            const fundSoftCap = await swarmPoweredFundraiseMock.softCap();
            const fundHardCap = await swarmPoweredFundraiseMock.hardCap();
            const fundBaseCurrency = await swarmPoweredFundraiseMock.baseCurrency();

            assert.equal(label === fundLabel, true);
            assert.equal(src20 === fundSrc20, true);
            assert.equal(fundTokenAmount.eq(tokenAmount), true);
            assert.equal(fundStartDate.eq(startDate), true);
            assert.equal(fundEndDate.eq(endDate), true);
            assert.equal(fundSoftCap.eq(softCap), true);
            assert.equal(fundHardCap.eq(hardCap), true);
            assert.equal(fundBaseCurrency === baseCurrency, true);
        });

        it('should fail if fundraising is started without src20 token', async function () {
            await shouldFail.reverting.withMessage(
                SwarmPoweredFundraiseMock.new(
                    label,
                    constants.ZERO_ADDRESS,
                    tokenAmount,
                    startDate,
                    endDate,
                    softCap,
                    hardCap,
                    baseCurrency,
                    {from: issuer}),
                "Fundraising deployment failed: SRC20 token can not be zero address");
        });

        it('should allow token issuer to set src20 token price', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer});
            const fundTokenPrice = await swarmPoweredFundraiseMock.tokenPriceBCY();
            assert.equal(fundTokenPrice.eq(tokenPrice), true);
        });

        it('should allow token issuer to set total amount of src20 tokens', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer});
            const fundTotalTokenAmount = await swarmPoweredFundraiseMock.totalTokenAmount();
            assert.equal(fundTotalTokenAmount.eq(totalTokenAmount), true);
        });

        it('should not allow token issuer to set src20 token price if total amount of tokens are already set', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer});

            await shouldFail.reverting.withMessage(
                swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer}),
                "Failed to set token price, total token amount already set");
        });

        it('should not allow token issuer to set total amount of src20 tokens if price is already set', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer});

            await shouldFail.reverting.withMessage(
                swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer}),
                "Failed to set total token amount, token price already set");
        });

        it('should not be able to contribute if fundraising did not start');

        it('should be able to set hard and soft cap on fundraising deployment');

        // Locking contributions
        it('should be able to withdraw contribution if contributions withdrawal are allowed');

        it('should be able to put presale amount and presale tokens with seperate functions');

        it('should fail if presale amount is larger than hardcap');

        it('should fail if presale tokens is larger than total amount of tokens');

        it('should be able to set base currency from accepted currencies');

        it('should not be able to set base currency from not accepted currencies');

        it('should pass contribution rules');

        it('should fail contribution rules');
    });
});
