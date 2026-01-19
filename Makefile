.PHONY: install build test deploy deploy-anvil

# -----------------------------
# Configuration
# -----------------------------
SEPOLIA_RPC ?= $(SEPOLIA_RPC_URL)
PRIVATE_KEY ?= $(DEPLOYER_PRIVATE_KEY)

ANVIL_RPC = http://127.0.0.1:8545
ANVIL_PRIVATE_KEY = 0x59c6995e998f97a5a0044976f89d8b36b9d7f4c8f0f2f9a6d6d3bfa2c4f7b99f
# ↑ Anvil default account #0

SCRIPT = script/Deploy.s.sol:Deploy

# -----------------------------
# Targets
# -----------------------------

install:
	@echo "🔧 Installing dependencies..."
	forge install OpenZeppelin/openzeppelin-contracts
	forge install foundry-rs/forge-std

build:
	@echo "🏗  Building contracts..."
	forge build

test:
	@echo "🧪 Running tests..."
	forge test -vv

deploy:
ifndef SEPOLIA_RPC
	$(error SEPOLIA_RPC is not set)
endif
ifndef PRIVATE_KEY
	$(error PRIVATE_KEY is not set)
endif
	@echo "🚀 Deploying to Sepolia..."
	forge script $(SCRIPT) \
		--rpc-url $(SEPOLIA_RPC) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvv

deploy-anvil:
	@echo "⚙️  Deploying to Anvil (local)..."
	forge script $(SCRIPT) \
		--rpc-url $(ANVIL_RPC) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast \
		-vvv
