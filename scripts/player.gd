
extends KinematicBody2D

# This is a simple collision demo showing how
# the kinematic controller works.
# move() will allow to move the node, and will
# always move it to a non-colliding spot,
# as long as it starts from a non-colliding spot too.

# Member variables
const GRAVITY = 500.0 # Pixels/second

# Angle in degrees towards either side that the player can consider "floor"
const FLOOR_ANGLE_TOLERANCE = 40
const WALK_FORCE = 600
const WALK_MIN_SPEED = 10
const WALK_MAX_SPEED = 200
const STOP_FORCE = 1300
const JUMP_SPEED = 320
const JUMP_MAX_AIRBORNE_TIME = 0.2

const SLIDE_STOP_VELOCITY = 1.0 # One pixel per second
const SLIDE_STOP_MIN_TRAVEL = 1.0 # One pixel

var velocity = Vector2()
var on_air_time = 100
var jumping = false
var dir_right = true

var prev_jump_pressed = false
var pApple = preload("res://scenes/items/apple.tscn")

func animation_walk():
	if int(get_pos().x) % 50 < 25:
		get_node("sprites").set_frame(0)
	else:
		get_node("sprites").set_frame(1)

func animation_jump():
	get_node("sprites").set_frame(1) # walking animation is fine for jumping, but this should be changed



func _fixed_process(delta):
	# Create forces
	var force = Vector2(0, GRAVITY)
	
	var walk_left = Input.is_action_pressed("move_left")
	var walk_right = Input.is_action_pressed("move_right")
	var jump = Input.is_action_pressed("jump")
	
	var stop = true
	
	if walk_left and get_pos().x > 32:
		if (velocity.x <= WALK_MIN_SPEED and velocity.x > -WALK_MAX_SPEED):
			force.x -= WALK_FORCE
			stop = false
			if not jumping:
				animation_walk()
			get_node("sprites").set_flip_h(true)
			dir_right = false

	elif walk_right and get_pos().x < get_node("Camera2D").get_limit(MARGIN_RIGHT)-32:
		if (velocity.x >= -WALK_MIN_SPEED and velocity.x < WALK_MAX_SPEED):
			force.x += WALK_FORCE
			stop = false
			if not jumping:
				animation_walk()
			get_node("sprites").set_flip_h(false)
			dir_right = true
			
	else:
		get_node("sprites").set_frame(0)
	
	if (stop):
		var vsign = sign(velocity.x)
		var vlen = abs(velocity.x)
		
		vlen -= STOP_FORCE*delta
		if (vlen < 0):
			vlen = 0
		
		velocity.x = vlen*vsign
	
	if (jumping):
		animation_jump()
	
	# Integrate forces to velocity
	velocity += force*delta
	
	# Integrate velocity into motion and move
	var motion = velocity*delta
	
	# Move and consume motion
	motion = move(motion)
	
	var floor_velocity = Vector2()
	var down_ray = get_node("check_down")
	
	if is_colliding():
		# You can check which tile was collision against with this
		# print(get_collider_metadata())
		
		# Ran against something, is it the floor? Get normal
		var n = get_collision_normal()
		
		if (rad2deg(acos(n.dot(Vector2(0, -1)))) < FLOOR_ANGLE_TOLERANCE):
			# If angle to the "up" vectors is < angle tolerance
			# char is on floor
			on_air_time = 0
			floor_velocity = get_collider_velocity()
		
		if (on_air_time == 0 and force.x == 0 and get_travel().length() < SLIDE_STOP_MIN_TRAVEL and abs(velocity.x) < SLIDE_STOP_VELOCITY and get_collider_velocity() == Vector2()):
			# Since this formula will always slide the character around, 
			# a special case must be considered to to stop it from moving 
			# if standing on an inclined floor. Conditions are:
			# 1) Standing on floor (on_air_time == 0)
			# 2) Did not move more than one pixel (get_travel().length() < SLIDE_STOP_MIN_TRAVEL)
			# 3) Not moving horizontally (abs(velocity.x) < SLIDE_STOP_VELOCITY)
			# 4) Collider is not moving
			
			revert_motion()
			velocity.y = 0.0
		else:
			# For every other case of motion, our motion was interrupted.
			# Try to complete the motion by "sliding" by the normal
			motion = n.slide(motion)
			velocity = n.slide(velocity)
			# Then move again
			move(motion)
	
	elif(down_ray.is_colliding()):
		var collider = down_ray.get_collider()
		if collider != null and collider extends StaticBody2D:
			floor_velocity = collider.get_constant_linear_velocity()
	
	#print(floor_velocity)
	if (floor_velocity != Vector2()):
		# If floor moves, move with floor
		move(floor_velocity*delta)
		if(is_colliding()):
			revert_motion()
	
	if (jumping and velocity.y > 0):
		# If falling, no longer jumping
		jumping = false

	if (on_air_time < JUMP_MAX_AIRBORNE_TIME and jump and not prev_jump_pressed and not jumping):
		# Jump must also be allowed to happen if the character left the floor a little bit ago.
		# Makes controls more snappy.
		velocity.y = -JUMP_SPEED
		jumping = true
		get_node("/root/world/SamplePlayer").play("jump")
	
	on_air_time += delta
	prev_jump_pressed = jump
	
	if get_pos().y > get_node("Camera2D").get_limit(MARGIN_BOTTOM)+32:
		queue_free()
		get_node("/root/world/").restart()

func _input(event):
	if not event.is_echo() && event.is_pressed():
		if global.apples > 0 and event.is_action("throw"):
			var apple = pApple.instance()
			apple.set_pos(get_pos())
			apple.add_collision_exception_with(self)
			apple.set_z(2)
			get_parent().add_child(apple)
			get_node("/root/world").remove_apple()

func _ready():
	get_node("check_right").add_exception(self)
	get_node("check_down").add_exception(self)
	set_fixed_process(true)
	set_process_input(true)
