const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const SwarmPoweredFundraiseFinished = artifacts.require('SwarmPoweredFundraiseFinished');
const SwarmPoweredFundraiseCanceled = artifacts.require('SwarmPoweredFundraiseCanceled');
const SwarmPoweredFundraiseExpired = artifacts.require('SwarmPoweredFundraiseExpired');
const Erc20Token = artifacts.require('SwarmTokenMock');

contract('ContributorActions', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
    const ercTotalSupply = new BN(10000);
    const amount = new BN(10);
    const minAmount = new BN(11);
    const maxAmount = new BN(100);

    beforeEach(async function () {
        this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new({from: owner}); // @TODO change owner to be token issuer...

        this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new({from: owner});
        this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new({from: owner});
        this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new({from: owner});

        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    });

    describe('Fundraising whitelist functionality', () => {
        it('', {
            // should be able to whitelist as a issuer/manager
            // increase total sum per contributor check
            // increase historical balances only if contrition rule is met check
            // move contributions to acc contribution if contribution rule are met check

            // new contribution
            // increase total sum per contributor check
            // increase historical balances only if contrition rule is met check
            // move contributions to acc contribution if contribution rule are met check

            // should be able to de-whitelist account
            // decrease total sum per contributor check
            // increase hardcap for sum per contributor only if contrition rule is met check
            // remove contributions from acc contributions

            // new contribution
            // increase total sum per contributor check

            // cannot whitelist/ de-whitelist after finished/expired/canceled fundraising
        });

        it('should be able to whitelist as a issuer');

        it('should be able to whitelist as a manager');

        it('should not be able to whitelist as not-authorized account');

        it('should be able for contribution to automatically be moved to accepted contributions if contributor has been whitelist');

        it('should be able to accept contribution if contributor is already on whitelist');

        it('should be able to de-whitelist as a issuer');

        it('should be able to de-whitelist as a manager');

        it('should not be able to de-whitelist as non-authorized account');

        it('should not be able accept contribution if contributor is de-whitelisted');

        it('should not be able to whitelist if fundraising is finished');

        it('should not be able to whitelist if fundraising is expired');

        it('should not be able to whitelist if fundraising is canceled');

        it('should not be able to de-whitelist if fundraising is finished');

        it('should not be able to de-whitelist if fundraising is expired');

        it('should not be able to de-whitelist if fundraising is canceled');
    });
});