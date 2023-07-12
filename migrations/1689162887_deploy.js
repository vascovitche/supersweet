const SweetToken = artifacts.require("SweetToken");
const Vote = artifacts.require("Vote");

module.exports = async function(deployer) {
  await deployer.deploy(SweetToken);

  const Token = await SweetToken.deployed();

  await deployer.deploy(Vote, Token.address, 'human', 'bot');

};

