const Sweet = artifacts.require('Sweet');


module.exports = async function (_deployer) {

    let hero1 = 'human';
    let hero2 = 'bot';

    await _deployer.deploy(Sweet, hero1, hero2);
};
