-include .env
export

deployFactory:; forge script script/DeployFactory.s.sol:DeployFactory --account $(ACCOUNT) --rpc-url $(RPC_URL) --broadcast

deployRouter:; forge script script/DeployRouter.s.sol:DeployRouter --account $(ACCOUNT) --rpc-url $(RPC_URL) --broadcast

#deployERC20:; forge script script/DeployERC20Factory.s.sol:DeployERC20Factory --account $(ACCOUNT) --rpc-url $(RPC_URL) --broadcast

deployFactoryToken:; forge script script/DeployFactoryToken.s.sol:DeployFactoryToken --account $(ACCOUNT) --rpc-url $(RPC_URL) --broadcast
