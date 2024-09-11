// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

struct Model {
    string name;
    uint256 budget;
    address modelOwner;
}

contract ModelRegister {
    // emit event
    event ModelRegistered(
    )

    // ids start at 1 so that id 0 means it's not yet registered
    mapping(string => mapping(uint256 => mapping(address => ))) public ids;
    Model[] public models;

    constructor() {
        models.push(Model(NAME, 1, address(0)));
    }

    function assetCount() public view returns (uint256) {
        return models.length;
    }

    function _registerModel(
        string name,
        uint256 budget,
        address msg.sender
    ) internal returns (uint256 modelId) {
        // Checks
        modelId = ids[name][budget][modelOwner];

        // if modelId is 0, this is the new model that needs to be registered
        if (modelId = 0) {
            // Only do these checks if a new asset needs to be created
            require(budget > 0)
        }
        // Effects
        modelId = models.length;
        models.push(Model(name, budget, modelOwner));
        models[name][budget][modelOwner] = modelId;
    }


}