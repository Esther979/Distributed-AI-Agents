/**
* Name: guest
* Based on the internal empty template. 
* Author: esther
* Tags: 
*/


model festival

/* Insert your model definition here */
global{
	int numberOfPeople <- 10;
	int numberOfStores <- 4;
	int distanceThreshold <-20;
	
	init{
		create InformationCenter number:1;
		create Person number:numberOfPeople;
		create Store number:numberOfStores;
		
		loop counter from: 1 to: numberOfPeople{
			Person my_agent <- Person[counter - 1];
			//my_agent <- my_agent.setName(counter);
			ask my_agent { do setName(counter); }
		}
		
		loop counter from:1 to:numberOfStores{
			Store my_store <- Store[counter-1];
			//my_agent <- my_agent.setName(counter);
			ask my_store { do setName(counter); }
		}
	}
}
species InformationCenter {

	/* 返回最近满足需求的店，而不是返回列表 */
	action findStore(Person p){
		list<Store> candidates <- [];

		if (p.isHungry) {
			candidates <- candidates + (Store where (each.hasFood));
		}
		if (p.isThirsty) {
			candidates <- candidates + (Store where (each.hasDrink));
		}

		if (empty(candidates)) {
			return nil;
		}

		/* 返回最近的一个店 */
		list<Store> sorted <- candidates sort_by (each.location distance_to p.location);
		return first(sorted);
	}

	aspect base {
		draw triangle(3) color: rgb("blue");
	}
}



species Person skills:[moving]{
	bool isHungry  <- flip(0.5);
	bool isThirsty <- flip(0.5);


	string personName <- "Undefined";
	Store targetStore <- nil;
	InformationCenter center <- one_of(InformationCenter);

	action setName(int num){
		personName <- "Person" + num;
	}

	aspect base{
		rgb agentColor <- rgb("green");

		if(isHungry and isThirsty){
			agentColor <- rgb("red");
		} else if (isThirsty){
			agentColor <- rgb("darkorange");
		} else if (isHungry){
			agentColor <- rgb("purple");
		}
		draw circle(1) color:agentColor;
	}

	/* 持续变饿变渴 */
	reflex randomNeeds {
			if (not isHungry and flip(0.01)) { isHungry <- true; }
			if (not isThirsty and flip(0.012)) { isThirsty <- true; }
		}

	/* 问路 */
	reflex askCenter when: (isHungry or isThirsty) and (targetStore = nil) {
		ask center {
			myself.targetStore <- findStore(myself); // 使用 myself 前缀
		}
	}

	/* 去商店 */
	reflex goToStore when: targetStore != nil {
		do goto target: targetStore speed: 1.0;

		if (location distance_to targetStore.location < 1.5) {
			/* 到店后补充对应属性 -> 变回绿色 */
			if (isHungry and targetStore.hasFood)  { isHungry  <- false; }
			if (isThirsty and targetStore.hasDrink){ isThirsty <- false; }
			targetStore <- nil; // 回到闲逛/等待状态
		}
	}

	/* 原本你自己的 wander 行为 */
	reflex move when: targetStore = nil {
		do wander;
	}
	
	reflex reportApproachingToStore when: !empty(Store at_distance distanceThreshold){
		write "The number of close stores to agent" + personName + "is" + length(list(Store at_distance distanceThreshold));
		ask Store at_distance distanceThreshold{
			write myself.personName + "is near" + self.storeName;
		}
	}
}

species Store {
	bool hasFood <- flip(0.5);
	bool hasDrink <- flip(0.5);
	string storeName <- "Undefined";
	
	action setName(int num){
		storeName <- "Store" + num;
	}
	
	aspect base{
		rgb agentColor;
		if(hasFood and hasDrink){
			agentColor <- rgb("purple");
		} else if (hasFood) {
			agentColor <- rgb("skyblue");
		} else{
			agentColor <- rgb("lightskyblue");
		}
		draw square(2) color:agentColor;
	}
}

experiment myExperiment type: gui{
	output{
		display myDisplay{
			species Person aspect:base;
			species Store aspect:base;
		}
	}
}