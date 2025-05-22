@tool class_name ThreadsWorker extends Resource

signal task_completed(result)

## [ATTENTION] -- To Do : Implement task sorting by distance

var tasks_queue :Array[Callable] = []

var processed = [];
var processing = [];

func _init(thread_count: int = 4):
	shutdown()

func add_task(callable : Callable, id):
	if id != null && id in processed:
		return;
	processed.append(id);
	tasks_queue.append(callable);
	print("Task added:",tasks_queue.size())

var delay = 8;
var waited = 0;

func update(_delta):
	var md = 40;
	var balance_step = 0.05;
	
	if Engine.get_frames_per_second() < md:
		delay = clamp(delay + balance_step, 0, md/2);
	else:
		delay = clamp(delay - balance_step, 0, md/2);
	
	if waited < delay:
		waited += 1;
		return;
	else:
		waited = 0;
	
	
	#for id in range(processing.size() -1, -1, -1):
		#if WorkerThreadPool.is_task_completed(processing[id]):
			#processing.remove_at(id);
	
	if !tasks_queue.is_empty():
		var next_task: Callable = tasks_queue.pop_back();
		print("Calling task, ramain:", tasks_queue.size()," calls t:",delay)
		next_task.call()
		#var id = WorkerThreadPool.add_task(next_task);
		#processing.append(id);
		
		#next_task.call()

func shutdown():
	processing.clear();
	tasks_queue.clear()
	processed.clear();
