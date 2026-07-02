Plan:
	- Create 2d arena with 2 wizards (player & agent)
	- Given "Inputs", either a water, fire, nature or light projectile is cast, 
	  which slowly approaches the enemy wizard. Water beats fire beats nature beats light beats water.
	  Equal projectiles annihilate each other.
	- To make the game fun, I will connect the keyword detection model to replace the "Inputs",
		but in the meantime they can simply be assigned to keybinds as placeholder
	- The agent "knows" the first n projectiles on their way to him. He will try to counter with the
	  opposite elements. 
	- Two difficulty slider:
		1. Adjust agent casting speed
		2. Increase percentage of agent casts that are random elements instead of the optimal choice

Work in parallel:
	- 1 person responsible for visuals (arena & wizards & projectiles & buttons & score)
	- 1 person responsible for game logic (health & damage, signals, gameplay mechanics)
	- 1 person responsible for keyword detection and model behavior (Thomas)

Next steps:
	- I (Thomas) will define interfaces so everyone can start working in parallel
	- Everyone does their part, in parallel
	- Game finished.