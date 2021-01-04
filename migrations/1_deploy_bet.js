const ExerciseToken = artifacts.require("ExerciseToken");
const Bet = artifacts.require("Bet");

module.exports = async function (deployer) {
  await deployer.deploy(ExerciseToken);
  const exerciseToken = await ExerciseToken.deployed();
  await deployer.deploy(Bet, exerciseToken.address);
};
