ifneq (,$(wildcard .env))
    include .env
    export
endif


trade:
	@forge script scripts/ProfitableTrades.s.sol:ProfitableTrades \
	--rpc-url $(RPC_URL) --legacy --broadcast --sender ${OWNER_ADDRESS} --batch-size=21 \
	--sig "run()"