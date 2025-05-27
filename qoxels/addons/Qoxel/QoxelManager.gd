@tool
##This script provides a way to schedule and manage function calls during the 
##engine's process and physics process frames. It uses two separate arrays to 
##store callables for each type of frame:
##
##- "process_calls" for functions to be called during the regular _process frame.
##- "physics_process_calls" for functions to be called during the _physics_process frame.
##
##The script also includes a method "callp" which allows functions to be scheduled 
##for a specific frame type, while also avoiding duplicate calls if they have already 
##been scheduled in the same frame. The system supports both allowing and preventing 
##duplicate calls depending on the "allow_duplication" flag.
##
##This approach helps manage and organize function calls that need to be executed 
##at specific times during the game's frame updates, either during the regular process 
##loop or the physics processing step.

extends Node

## Enum to define call modes for functions (either PROCESS or PHYSICS_PROCESS).
enum CALL_MODE {
	PROCESS,           ## Functions to be called in the regular _process frame.
	PHYSICS_PROCESS    ## Functions to be called in the _physics_process frame.
}

## Array to store Callable functions for regular processing (_process).
var process_calls : Array[Callable] = [];

## Array to store Callable functions for physics processing (_physics_process).
var physics_process_calls : Array[Callable] = [];

## Called every frame by the engine during the physics processing step.
## Loops through the functions queued in physics_process_calls and calls them.
## Clears the list of called functions after execution.
func _physics_process(delta: float) -> void:
	if !physics_process_calls.is_empty():
		for call in physics_process_calls:
			if call != null && call is Callable && is_instance_valid(call.get_object()):
				call.call();
		physics_process_calls.clear();

## Called every frame by the engine during the regular processing step.
## Loops through the functions queued in process_calls and calls them.
## Clears the list of called functions after execution.
func _process(delta: float) -> void:
	if !process_calls.is_empty():
		for call in process_calls:
			call.call();
		process_calls.clear();

## Method to schedule a function to be called either in the regular process or the physics process frame.
## It allows avoiding duplicate calls by checking if the same function with the same arguments
## is already in the respective call list.
## @param callable: The function to be called.
## @param allow_duplication: If true, allows the same function to be scheduled multiple times. Default is false.
## @param call_mode: Determines if the function should be added to regular processing (_process) or physics processing (_physics_process). Default is PROCESS.
func callp(callable : Callable, allow_duplication : bool = false, call_mode : CALL_MODE = CALL_MODE.PROCESS) -> void:
	var calls : Array[Callable] = process_calls;
	
	# Select the appropriate array based on the call mode.
	if call_mode == CALL_MODE.PHYSICS_PROCESS:
		calls = physics_process_calls;
	
	# If duplication is not allowed, check if the function is already scheduled.
	if !allow_duplication:
		for _call in calls:
			if _call.get_object() == callable.get_object() && _call.get_method() == callable.get_method() && _call.get_bound_arguments() == callable.get_bound_arguments():
				return;
	
	# Append the function to the respective call list.
	calls.append(callable);
