extends SceneTree
## Real software-Vulkan district architectural pilot screenshots.
const IDS: Array[String]=[
	"harbour/office","harbour/net_store","craft/tomas_workshop",
	"chapel/ordinary_hall","district/mara_home","service/landing_pier",
	"service/boatyard_base","district/upper_cottage_cluster_study",
	"chapel/schoolroom_wing","chapel/aldren_study",
	"harbour/navigation_light"]
const SHORT: Array[String]=["office","net_store","workshop","chapel","mara_home",
	"landing_pier","boatyard","upper_house","schoolroom","aldren_study","navigation_light"]
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var folder: String=OS.get_environment("HOLLOWMERE_G3_PILOT_RENDER_DIR")
	if folder.is_empty():
		push_error("G3 render folder env missing")
		quit(1)
		return
	var stage:=HMBrinewickBlockout.new()
	stage.spawn_exploration_player=false
	root.add_child(stage)
	var cam:=Camera3D.new()
	cam.current=true
	cam.fov=66.0
	cam.far=200.0
	stage.add_child(cam)
	var errors:=0
	for i: int in range(IDS.size()):
		var group: Node3D=stage.district_sites.installation_nodes[IDS[i]]
		var target: Vector3=group.global_position
		cam.global_position=target+Vector3(9.2,5.3,12.8)
		cam.look_at(target+Vector3(0,2.2,0),Vector3.UP)
		for frame: int in range(22):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image=root.get_texture().get_image()
		if img==null or img.get_width()<640:
			push_error("No Vulkan render "+SHORT[i])
			errors+=1
			continue
		if img.save_png(folder.path_join("g3-pilot-"+SHORT[i]+".png"))!=OK:
			errors+=1
	stage.queue_free()
	await process_frame
	if errors==0:
		print("HOLLOWMERE_G3_ELEVEN_VULKAN_INSTALLATIONS_OK")
		quit(0)
	else:
		quit(1)
