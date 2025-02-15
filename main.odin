package main
import "core:fmt"
import "core:time"
import "core:math"
import "core:sort"
import sdl "vendor:sdl2"

log_types::enum{
    INFO,
    WARN,
    ERROR
}
RED:u32=0xFFFF0000
YELLOW:u32=0xFFFFFF00
PURPLE_GRAY:u32=0xFF3C2F47
template_color:u32=0xFF000000
current_color:u32=0x00FF00FF
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
is_drawing:bool =false
is_drawing_rectangle:bool=false
initial_rectangle_point:vec2_t = vec2_t{-1,-1}
is_drawing_circle:bool= false
initial_circle_point:vec2_t = vec2_t{-1,-1}
is_drawing_ellipse:bool=false
initial_ellipse_point:vec2_t = vec2_t{-1,-1}
is_drawing_triangle:bool = false
initial_triangle_point:vec2_t = vec2_t{-1,-1}
is_drawing_line_shape:bool=false
initial_line_shape_point:vec2_t = vec2_t{-1,-1}
is_x_pressed:bool= false
is_deleting_area:bool = false
reset_shape_point::proc(shape:^vec2_t){
    shape.x,shape.y = -1,-1
}
distance_between_points::proc(p1:vec2_t,p2:vec2_t)->(distance:f32){
    dx := math.abs(p1.x-p2.x)
    dy := math.abs(p1.y-p2.y)
    return math.sqrt(dx*dx + dy*dy)
}
draw_ellipse :: proc(center_x, center_y, radius_x, radius_y: f32, color: u32) {
    rx := f32(radius_x)
    ry := f32(radius_y)
    cx := f32(center_x)
    cy := f32(center_y)

    x :f32= 0
    y :f32= ry
    dx :f32= 0
    dy :f32= 2 * rx * rx * y
    err := ry * ry - rx * rx * ry
    for rx * rx * y >= ry * ry * x {
        draw_fat_pixel(cx + x, cy + y, color)
        draw_fat_pixel(cx - x, cy + y, color)
        draw_fat_pixel(cx + x, cy - y, color)
        draw_fat_pixel(cx - x, cy - y, color)

        if err <= 0 {
            x += 1
            dx += 2 * ry * ry
            err += dx + ry * ry
        } else {
            y -= 1
            dy -= 2 * rx * rx
            err += rx * rx - dy
        }
    }
    // Second region; y decreasing, x increasing
    x = rx
    y = 0
    dx = 2 * ry * ry * x
    dy = 0
    err = ry * ry - rx * rx * rx
    for ry * ry * x >= rx * rx * y {
        draw_fat_pixel(cx + x, cy + y, color)
        draw_fat_pixel(cx - x, cy + y, color)
        draw_fat_pixel(cx + x, cy - y, color)
        draw_fat_pixel(cx - x, cy - y, color)
        if err <= 0 {
            y += 1
            dy += 2 * rx * rx
            err += dy + rx * rx
        } else {
            x -= 1
            dx -= 2 * ry * ry
            err += ry * ry - dx
        }
    }
}
draw_triangle :: proc(p1, p2, p3: vec2_t, color: u32) {
    draw_line(p1.x, p1.y, p2.x, p2.y, color)
    draw_line(p2.x, p2.y, p3.x, p3.y, color)
    draw_line(p3.x, p3.y, p1.x, p1.y, color)

}
draw_circle :: proc(center: vec2_t, radius: f32, color: u32) {//copied from llm
    x := f32(radius)
    y : f32 = 0
    p : f32 = 1 - f32(radius) // Initial decision parameter
    // Draw the circle using symmetry
    for x >= y {
        // Plot points in all octants
        draw_fat_pixel(center.x + x, center.y + y, color)
        draw_fat_pixel(center.x + y, center.y + x, color)
        draw_fat_pixel(center.x - y, center.y + x, color)
        draw_fat_pixel(center.x - x, center.y + y, color)
        draw_fat_pixel(center.x - x, center.y - y, color)
        draw_fat_pixel(center.x - y, center.y - x, color)
        draw_fat_pixel(center.x + y, center.y - x, color)
        draw_fat_pixel(center.x + x, center.y - y, color)

        y += 1
        // Update decision parameter
        if p <= 0 {
            p = p + 2 * y + 1
        } else {
            x -= 1
            p = p + 2 * y - 2 * x + 1
        }
    }
}

is_window_running:bool = false
renderer:^sdl.Renderer = nil
window : ^sdl.Window = nil
color_buffer:[WINDOW_HEIGHT][WINDOW_WIDTH]u32
color_buffer_texture: ^sdl.Texture = nil
drawing_buffer:[]u32
is_d_pressed:bool = false
is_r_pressed:bool = false
is_c_pressed:bool = false
is_t_pressed:bool = false
is_e_pressed:bool = false
is_l_pressed:bool = false

//storing the previous mouse position to draw the line from the previous point to new mouse point for continious line
prev_mouse_pos: vec2_t = {-1,-1}

vec2_t :: struct{
    x:f32,
    y:f32
}
vec3_t :: struct{
    x:f32,
    y:f32,
    z:f32
}
pixel_data::struct{
    x:f32,
    y:f32,
    color:u32
}
Lasso_Boundary_Point::struct{
    least_x:f32,
    least_y:f32,
    most_x:f32,
    most_y:f32
}
reset_pixel_to_default_template::proc(pixel:^pixel_data){
    draw_pixel(pixel.x,pixel.y,template_color)
}
id_of_current_line:u128=0
Line_Data::struct{
    line_start:struct{x:f32,y:f32},
    line_end:struct{x:f32,y:f32},
    thickness:u32,
    color:u32
}
rectangle_shape_data::struct{
    initialization_point:vec2_t,
    final_point:vec2_t
}
circle_shape_data::struct{
    initialization_point:vec2_t,
    final_point:vec2_t,
    color:u32
}
ellipse_shape_data::struct{
    initialization_point:vec2_t,
    final_point:vec2_t
}
triangle_shape_data::struct{
    initialization_point:vec2_t,
    final_point:vec2_t,
}
line_shape_data::struct{
    initialization_point:vec2_t,
    final_point:vec2_t,
}
Fill_Data::struct{
    initialization_point:struct{x:f32, y:f32},
    color_to_be_replaced_with:u32,
    color_to_be_replaced:u32
}
Lasso_Data::struct{
    center:vec2_t,
    radius:f32,
    fill_color:u32
}
Drawing_Type::enum{
    LINE,
    FILL,
    RECTANGLE_SHAPE,
    CIRCLE_SHAPE,
    ELLIPSE_SHAPE,
    TRIANGLE_SHAPE,
    LINE_SHAPE,
    LASSO
}
Line::struct{
    data:union{
        Line_Data,
        Fill_Data,
        rectangle_shape_data,
        circle_shape_data,
        ellipse_shape_data,
        triangle_shape_data,
        line_shape_data,
        Lasso_Data
    },
    drawing_type:Drawing_Type,
    line_id:u128
}
Stack::struct(T:typeid){
    data:[dynamic]T
}
stack_init::proc(stack:^Stack($T)){
    stack.data = make([dynamic]T)
}
stack_push::proc(stack:^Stack($T),value:T){
    append(&stack.data,value)
}
stack_pop::proc(stack:^Stack($T))->(value:T,ok:bool){
    if len(stack.data)>0{
        log_info("A value has been remove from Stack")
        value = stack.data[len(stack.data)-1]
        ok=true
        pop(&stack.data)
    }else{
        ok=false
    }
    return
}
stack_peek :: proc(stack: ^Stack($T))->(value:T,ok:bool){
    if len(stack.data)>0{
        value = stack.data[len(stack.data)-1]
        ok=true
    }else{
        ok=false
    }
    return
}
stack_free :: proc(stack: ^Stack($T)) {
    delete(stack.data)
}

Line_Stack : Stack(Line)
Undo_Stack : Stack(Line)
draw_line_from_stack::proc(stack:^Stack(Line)){
    for i in 0..<len(stack.data){
        d:=stack.data[i]
        switch d.drawing_type{
            case .LINE:{
                line_data:=d.data.(Line_Data)
                color:=d.data.(Line_Data).color
                thickness:=line_data.thickness
                x_start,y_start:=line_data.line_start.x,line_data.line_start.y
                x_end,y_end:=line_data.line_end.x,line_data.line_end.y
                draw_line(x_start,y_start,x_end,y_end,color)
            }
            case .FILL:{
                fill_data:=d.data.(Fill_Data)
                fill_color:=fill_data.color_to_be_replaced_with
                existing_color_that_will_be_replaced:=fill_data.color_to_be_replaced
                x,y:=fill_data.initialization_point.x,fill_data.initialization_point.y
                fill_area(x,y,fill_color,existing_color_that_will_be_replaced)
            }
            case .LASSO:{
                lasso_data:=d.data.(Lasso_Data)
                fill_color:=lasso_data.fill_color
                radius:=lasso_data.radius
                c_x,c_y:=lasso_data.center.x,lasso_data.center.y
                fill_circle_area(c_x,c_y,radius,fill_color)
            }
            case .RECTANGLE_SHAPE:{
                data:= d.data.(rectangle_shape_data)
                x_initial,y_initial:=data.initialization_point.x,data.initialization_point.y
                x_final,y_final:=data.final_point.x,data.final_point.y
                length:= math.abs(x_initial-x_final)
                height:=math.abs(y_initial-y_final)
                //two points of rectangle
                predicted_point_1_x,predicted_point_1_y:=x_initial,y_final
                predicted_point_2_x,predicted_point_2_y:=x_final,y_initial
                //to make not too verbose code
                initial:=vec2_t{x_initial,y_initial}
                final:=vec2_t{x_final,y_final}
                pp1:=vec2_t{predicted_point_1_x,predicted_point_1_y}
                pp2:=vec2_t{predicted_point_2_x,predicted_point_2_y}
                color:u32=current_color
                draw_line(initial.x, initial.y, pp1.x, pp1.y, color)
                draw_line(initial.x, initial.y, pp2.x, pp2.y, color)
                draw_line(final.x, final.y, pp1.x, pp1.y, color)
                draw_line(final.x, final.y, pp2.x, pp2.y, color)

            }
            case .CIRCLE_SHAPE:{
                data:=d.data.(circle_shape_data)
                color:=data.color
                initial:=vec2_t{data.initialization_point.x,data.initialization_point.y}
                final:=vec2_t{data.final_point.x,data.final_point.y}
                diameter:=distance_between_points(initial,final)
                radius:=diameter/2
                center:=vec2_t{(initial.x+final.x)/2,(initial.y+final.y)/2}
                draw_circle(center,radius,color)
            }
            case .ELLIPSE_SHAPE:{
                data:=d.data.(ellipse_shape_data)
                initial:=vec2_t{data.initialization_point.x,data.initialization_point.y}
                final:=vec2_t{data.final_point.x,data.final_point.y}
                radius_x:=distance_between_points(initial,vec2_t{final.x,initial.y})/2 //Horizontal radius
                radius_y:=distance_between_points(initial,vec2_t{initial.x,final.y})/2 //Vertical radius
                center:=vec2_t{(initial.x+final.x)/2,(initial.y+final.y)/2}
                color: u32 = current_color
            
                min_radius: f32 = 5 // Minimum radius
                if radius_x < min_radius {
                    radius_x = min_radius
                }
                if radius_y < min_radius {
                    radius_y = min_radius
                }
                draw_ellipse(center.x,center.y,radius_x,radius_y,color)
            }
            case .TRIANGLE_SHAPE:{
                data:=d.data.(triangle_shape_data)
                p1:=vec2_t{data.initialization_point.x,data.initialization_point.y}
                p_mid:=vec2_t{data.final_point.x,data.final_point.y}
                color: u32 = current_color
            
                height := math.abs(p1.y - p_mid.y)
                base_half_width := height
            
                p2 := vec2_t{p_mid.x - base_half_width, p_mid.y}
                p3 := vec2_t{p_mid.x + base_half_width, p_mid.y}
            
                draw_triangle(p1, p2, p3, color)
            }
            case .LINE_SHAPE:{
                data:=d.data.(line_shape_data)
                initial:=vec2_t{data.initialization_point.x,data.initialization_point.y}
                final:=vec2_t{data.final_point.x,data.final_point.y}
                color: u32 = current_color
                draw_line(initial.x,initial.y,final.x,final.y,color)
            }
        }
    }
}
fov_factor:f32 = 128
N_POINTS::9*9*9
//array of 3-d projected points
cube_points:[N_POINTS]vec3_t 
//array of orthogonally projected 3-d points
projected_points:[N_POINTS]vec2_t

log_info::proc(args:..any){
    log(log_types.INFO,args)
}

log_warn::proc(args:..any){
    log(log_types.WARN,args)
}

log_error::proc(args:..any){
    log(log_types.ERROR,args)
}

log :: proc(level:log_types,args:..any){
    now:=time.now()
    fmt.printf("[%v] [%v]:",now,level)
    fmt.println(..args)
}

swap_stack_elements_and_return_lineId::proc(to:^Stack(Line),from:^Stack(Line))->(line_id:u128,is_swapped:bool){
    if len(from.data)>0{
        value_popped, is_popped:=stack_pop(from)
        log_info("Value popped from stack")
        if is_popped{
            stack_push(to,value_popped)
            line_id = value_popped.line_id
            is_swapped = true
        }
    }
    return
}
swap_stack_elements_with_same_line_ids::proc(to:^Stack(Line),from:^Stack(Line),line_id_to_swap:u128){
    if len(from.data)>0{
        removed_line_id, is_swapped := swap_stack_elements_and_return_lineId(to,from)
        for{
            value,is_line_present:=stack_peek(from)
            if is_line_present==false || value.line_id!=removed_line_id {break}
            else {swap_stack_elements_and_return_lineId(to,from)}
        }
    }
}
perform_empty_check_and_swap_lines_among_stacks::proc(to:^Stack(Line),from:^Stack(Line)){
    if len(from.data)>0{//empty check
        //swapping lines amongst stack
        top_line_value,_:=stack_peek(from)
        line_id_to_be_removed:=top_line_value.line_id
        swap_stack_elements_with_same_line_ids(to,from,line_id_to_be_removed)
    }
}
fill_circle_area :: proc(center_x: f32, center_y: f32, radius: f32, fill_color: u32) {
    // Calculate the bounding box of the circle
    min_x := i32(center_x - radius)
    min_y := i32(center_y - radius)
    max_x := i32(center_x + radius)
    max_y := i32(center_y + radius)

    // Clamp to window boundaries
    min_x = max(0, min_x)
    min_y = max(0, min_y)
    max_x = min(i32(WINDOW_WIDTH - 1), max_x)
    max_y = min(i32(WINDOW_HEIGHT - 1), max_y)

    // Square of the radius for distance comparison
    radius_squared := radius * radius

    // Fill all pixels within the circle
    for y := min_y; y <= max_y; y += 1 {
        for x := min_x; x <= max_x; x += 1 {
            // Calculate distance from center using distance formula
            dx := f32(x) - center_x
            dy := f32(y) - center_y
            distance_squared := dx * dx + dy * dy

            // If point is inside circle, fill it
            if distance_squared <= radius_squared {
                draw_pixel(f32(x), f32(y), fill_color)
            }
        }
    }
}
fill_area :: proc(start_x: f32, start_y: f32, new_color: u32, target_color: u32) {
    if start_x < 0 || start_y < 0 || start_x >= WINDOW_WIDTH || start_y >= WINDOW_HEIGHT {
        return
    }
    log_info("Filling on the point",start_x,start_y)
    log_info("Filling, new color is",new_color==RED?"RED":"new_color",target_color==PURPLE_GRAY?"PURPLE_GRAY":"Fag")
    points_to_process := make([dynamic]vec2_t)
    defer delete(points_to_process)
    append(&points_to_process, vec2_t{start_x, start_y})
    for len(points_to_process) > 0 {
        current := points_to_process[len(points_to_process)-1]
        pop(&points_to_process)
        x, y := current.x, current.y
        if x < 0 || y < 0 || x >= WINDOW_WIDTH || y >= WINDOW_HEIGHT {
            continue
        }
        current_color := drawing_buffer[WINDOW_WIDTH * int(y) + int(x)]
        if current_color != target_color || current_color == new_color {
            continue
        }
        // Fill current pixel
        draw_pixel(x, y, new_color)

        // Add neighboring pixels to stack
        append(&points_to_process, vec2_t{x + 1, y}) // right
        append(&points_to_process, vec2_t{x - 1, y}) // left
        append(&points_to_process, vec2_t{x, y + 1}) // down
        append(&points_to_process, vec2_t{x, y - 1}) // up
    }
}
check_input :: proc(){
    log_info("Checking the input")
    event: sdl.Event
    for sdl.PollEvent(&event){  
        #partial switch event.type{
            case .QUIT:
                is_window_running = false
            case .KEYDOWN:
                key_event:= cast(^sdl.KeyboardEvent)&event
                #partial switch key_event.keysym.scancode{
                    case .ESCAPE:
                        is_window_running=false
                    case .D:
                        is_d_pressed = true
                        is_drawing = true
                        log_info("Drawing started (d pressed)")
                    case .U:
                        perform_empty_check_and_swap_lines_among_stacks(&Undo_Stack,&Line_Stack)
                    case .C:{
                        is_c_pressed = true
                        if is_d_pressed && !is_drawing_circle{
                            //d+c triggers circle
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_drawing_circle = true
                            initial_circle_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                    }
                    case .R:
                        is_r_pressed = true
                        //d+r triggers rectangle drawing
                        if is_d_pressed && !is_drawing_rectangle{
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_drawing_rectangle = true
                            initial_rectangle_point=vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                        //blocking the usual action of restoration since we are drawing shape
                        if is_drawing_rectangle{
                            continue
                        }
                        perform_empty_check_and_swap_lines_among_stacks(&Line_Stack,&Undo_Stack)
                    case .F:
                        x, y: i32
                        sdl.GetMouseState(&x, &y)
                        current_mouse_pos := vec2_t{f32(x), f32(y)}
                        new_fill_color:u32 = RED
                        existing_color:u32 = drawing_buffer[WINDOW_WIDTH * int(current_mouse_pos.y) + int(current_mouse_pos.x)] //We will be replacing pixel color that the mouse is at
                        //putting this point in the Line stack
                        stack_push(&Line_Stack,
                        Line{
                                Fill_Data{
                                    initialization_point = {current_mouse_pos.x,current_mouse_pos.y},
                                    color_to_be_replaced_with = new_fill_color,
                                    color_to_be_replaced = existing_color
                                },
                                Drawing_Type.FILL,//be mindful of this
                                id_of_current_line
                            }
                        )
                    case .L:{
                        is_l_pressed = true
                        if is_d_pressed && !is_drawing_line_shape{
                            //d+l triggers line drawing
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_drawing_line_shape = true
                            initial_line_shape_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                    }
                    case .T:{
                        is_t_pressed = true
                        if is_d_pressed && !is_drawing_triangle{
                            //d+t triggers triangle drawing
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_drawing_triangle = true
                            initial_triangle_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                    }
                    case .E:{
                        is_e_pressed = true
                        if is_d_pressed && !is_drawing_ellipse{
                            //d+e triggers ellipse drawing
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_drawing_ellipse = true
                            initial_ellipse_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                    }
                    case .X:{
                        //x denotes lasso delete
                        is_x_pressed=true
                        if is_d_pressed && !is_deleting_area{
                            x, y: i32
                            sdl.GetMouseState(&x, &y)
                            current_mouse_pos := vec2_t{f32(x), f32(y)}
                            is_deleting_area = true
                            initial_circle_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                            id_of_current_line+=1
                            continue
                        }
                    }
                }
            case .KEYUP:
                key_event := cast(^sdl.KeyboardEvent)&event
                #partial switch key_event.keysym.scancode {
                    case .D:
                        id_of_current_line+=1 //at this point a new line begins
                        log_info(`New line begins, incrementing current line id to`,id_of_current_line)
                        is_d_pressed = false
                        is_drawing = false
                        prev_mouse_pos = {-1, -1}  // Reset the previous mouse position
                        log_info("Drawing stopped (d released)")
                    case .C:
                        is_c_pressed = false
                        if is_drawing_circle {
                            is_drawing_circle = false
                            reset_shape_point(&initial_circle_point)
                            id_of_current_line+=1
                        }
                    case .R:
                        is_r_pressed = false
                        //this will mess with redo, must happen only when d+r is lifted up
                        if is_drawing_rectangle {
                            is_drawing_rectangle = false
                            reset_shape_point(&initial_rectangle_point)
                            id_of_current_line+=1
                        }
                    case .L:
                        is_l_pressed = false
                        if is_drawing_line_shape {
                            is_drawing_line_shape = false
                            reset_shape_point(&initial_line_shape_point)
                            id_of_current_line+=1
                        }
                    case .T:
                        is_t_pressed = false
                        if is_drawing_triangle {
                            is_drawing_triangle = false
                            reset_shape_point(&initial_triangle_point)
                            id_of_current_line+=1
                        }
                    case .E:
                        is_e_pressed = false
                        if is_drawing_ellipse {
                            is_drawing_ellipse = false
                            reset_shape_point(&initial_ellipse_point)
                            id_of_current_line+=1
                        }
                    case .X:
                        is_x_pressed = false
                        if is_deleting_area {
                            // When taking up x, the last item in stack will be a circle
                            // We will take it up, calculate its mid-point and perform fill-area 
                            // with template color to mimic lasso
                            top_value, ok := stack_peek(&Line_Stack)
                            last_circle_data := top_value.data.(circle_shape_data)
                            ip := last_circle_data.initialization_point
                            fp := last_circle_data.final_point
                            
                            if ok && top_value.drawing_type == Drawing_Type.CIRCLE_SHAPE && 
                                top_value.line_id == id_of_current_line {
                                center := vec2_t{(ip.x + fp.x)/2, (ip.y + fp.y)/2}
                                radius := distance_between_points(ip, fp) / 2
                                stack_push(&Line_Stack,
                                    Line{
                                        Lasso_Data{
                                            center = center,
                                            radius = radius,
                                            fill_color = template_color
                                        },
                                        Drawing_Type.LASSO,
                                        id_of_current_line
                                    }
                                )
                            }
                            
                            // Restoring the circle to template color
                            stack_push(&Line_Stack,
                                Line{
                                    circle_shape_data{
                                        initialization_point = vec2_t{ip.x, ip.y},
                                        final_point = vec2_t{fp.x, fp.y},
                                        color = template_color
                                    },
                                    Drawing_Type.CIRCLE_SHAPE,
                                    id_of_current_line
                                }
                            )
                            
                            is_deleting_area = false
                            reset_shape_point(&initial_circle_point)
                            id_of_current_line += 1
                        }
                }
            case .MOUSEMOTION:
                mouse_event := cast(^sdl.MouseMotionEvent)&event
                current_mouse_pos := vec2_t{f32(mouse_event.x), f32(mouse_event.y)}
                if is_d_pressed && is_deleting_area{
                    //copying algo from circle
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.CIRCLE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        circle_shape_data{
                            initialization_point = vec2_t{initial_circle_point.x,initial_circle_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y},
                            color= PURPLE_GRAY
                        },
                        Drawing_Type.CIRCLE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_d_pressed && is_drawing_circle{
                    //copying the algo from rectangle
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.CIRCLE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        circle_shape_data{
                            initialization_point = vec2_t{initial_circle_point.x,initial_circle_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y},
                            color = current_color
                        },
                        Drawing_Type.CIRCLE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_d_pressed && is_drawing_rectangle{
                    //Are we already in process of drawing a rectangle?
                    //I want to constantly render the rectangle as we move the mouse
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.RECTANGLE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        rectangle_shape_data{
                            initialization_point = vec2_t{initial_rectangle_point.x,initial_rectangle_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                        },
                        Drawing_Type.RECTANGLE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_d_pressed && is_drawing_ellipse{
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.ELLIPSE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        ellipse_shape_data{
                            initialization_point = vec2_t{initial_ellipse_point.x,initial_ellipse_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                        },
                        Drawing_Type.ELLIPSE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_d_pressed && is_drawing_triangle{
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.TRIANGLE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        triangle_shape_data{
                            initialization_point = vec2_t{initial_triangle_point.x,initial_triangle_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                        },
                        Drawing_Type.TRIANGLE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_d_pressed && is_drawing_line_shape{
                    for{
                        top_value,ok:=stack_peek(&Line_Stack)
                        if ok && top_value.drawing_type==Drawing_Type.LINE_SHAPE && top_value.line_id==id_of_current_line{
                            stack_pop(&Line_Stack)
                        }else{
                            break
                        }
                    }
                    stack_push(&Line_Stack,Line{
                        line_shape_data{
                            initialization_point = vec2_t{initial_line_shape_point.x,initial_line_shape_point.y},
                            final_point = vec2_t{current_mouse_pos.x,current_mouse_pos.y}
                        },
                        Drawing_Type.LINE_SHAPE,
                        id_of_current_line
                    })
                    prev_mouse_pos = current_mouse_pos
                    continue
                }
                if is_drawing{
                    if prev_mouse_pos=={-1,-1}{
                        prev_mouse_pos = current_mouse_pos
                    }
                    // In check_input's MOUSEMOTION case:
                    stack_push(&Line_Stack,
                    Line{
                        Line_Data{
                            line_start = {prev_mouse_pos.x, prev_mouse_pos.y},
                            line_end = {current_mouse_pos.x, current_mouse_pos.y},
                            thickness = 2,
                            color = 0xFF0000FF
                        },
                        Drawing_Type.LINE,
                        id_of_current_line//TODO:2 must be replaced with thickness when thickness fucntionality is implemented
                    }
                    )
                }
                prev_mouse_pos = current_mouse_pos
        }
    }
}
clear_color_buffer :: proc(color:u32){
    log_info("Clearing the color buffer")
    for y in 0..<WINDOW_HEIGHT{
        for x in 0..<WINDOW_WIDTH{
            color_buffer[y][x] = color
            drawing_buffer[WINDOW_WIDTH * int(y) + int(x)] = color
        }
    }
}

//Bresenham's line algorithm for connecting two points
draw_line :: proc(x0, y0, x1, y1: f32, color: u32) {
    x := x0
    y := y0

    dx := abs(x1 - x0)
    dy := abs(y1 - y0)
    sx :f32= x0 < x1 ? 1 : -1
    sy :f32= y0 < y1 ? 1 : -1
    err := dx - dy

    for {
        draw_fat_pixel(x, y, color)
        if x == x1 && y == y1 {
            break
        }
        e2 := 2 * err
        if e2 > -dy {
            err -= dy
            x += sx
        }
        if e2 < dx {
            err += dx
            y += sy
        }
    }
}

project :: proc(vector_point:vec3_t)->vec2_t{
    orthogonally_projected_point:vec2_t = {vector_point.x*fov_factor,vector_point.y*fov_factor};
    return orthogonally_projected_point
}

setup :: proc(){
    color_buffer_texture = sdl.CreateTexture(
        renderer,
        sdl.PixelFormatEnum.ARGB8888,
        sdl.TextureAccess.STREAMING,
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )
    point_count:=0
    for x:f32=-1;x<=1;x+=0.25{
        for y:f32=-1;y<=1;y+=0.25{
            for z:f32=-1;z<=1;z+=0.25{
                new_point:vec3_t = {x,y,z}
                cube_points[point_count] = new_point
                point_count+=1
            }
        }
    }
}

draw_grid::proc(){
    log_info("Drawing the grid")
    for y:=0;y<WINDOW_HEIGHT;y+=10{
        for x:=0;x<WINDOW_WIDTH;x+=10{
            color_buffer[y][x] = 0xFF333333
        }
    }
}
clear_buffer :: proc(buffer: []u32, color: u32) {
    for i in 0..<len(buffer) {
        buffer[i] = color
    }
}

draw_fat_pixel :: proc(x:f32,y:f32,color:u32){
    for y_index:=y;y_index<y+2;y_index+=1{
        for x_index:=x;x_index<x+2;x_index+=1{
            draw_pixel(x_index,y_index,color)
        }
    }
}

draw_pixel :: proc(x: f32, y: f32, color: u32) {
    if x >= 0 && x < WINDOW_WIDTH && y >= 0 && y < WINDOW_HEIGHT {
        drawing_buffer[WINDOW_WIDTH * int(y) + int(x)] = color
    }
}

draw_rect :: proc(x, y, width, height: f32, color: u32){
    for y_index:=y;y_index<y+height;y_index+=1{
        for x_index:=x;x_index<x+width;x_index+=1{
            draw_pixel(x_index,y_index,color)
        }
    }
}

 
render_color_buffer :: proc(){
    log_info("Rendering the color buffer by updating it to color_buffer_texture and copying it to renderer")
    //copying the contents of the drawing buffer to the color buffer
    for y in 0..<WINDOW_HEIGHT {
        for x in 0..<WINDOW_WIDTH {
            color_buffer[y][x] = drawing_buffer[WINDOW_WIDTH * y + x]
        }
    }
    sdl.UpdateTexture(
        color_buffer_texture,
        nil,
        &color_buffer,
        size_of(u32)*WINDOW_WIDTH
    )
    sdl.RenderCopy(
        renderer,
        color_buffer_texture,
        nil,
        nil 
    )
}

render_window :: proc() {
    clear_color_buffer(0xFF000000)
    draw_line_from_stack(&Line_Stack)    
    render_color_buffer()
    draw_grid()
    sdl.UpdateTexture(color_buffer_texture, nil, &color_buffer, size_of(u32)*WINDOW_WIDTH)
    sdl.RenderCopy(renderer, color_buffer_texture, nil, nil)
    sdl.RenderPresent(renderer)
}

update_window ::proc(){
    log_info("Updating window")
    for i:=0;i<N_POINTS;i+=1{
        //initializing cube_points at setup
        point:vec3_t = cube_points[i]
        projected_point:vec2_t = project(point)
        projected_points[i] = projected_point
    }
}
initialize_window :: proc() -> bool{
    //initializign everything
    log_info("Initializing window")
    if sdl.Init(sdl.INIT_EVERYTHING)<0{
        log_error("Error initializing SDL");
        return false
    }
    //initializing window
    window = sdl.CreateWindow("Velarium",sdl.WINDOWPOS_CENTERED,sdl.WINDOWPOS_CENTERED,WINDOW_WIDTH,WINDOW_HEIGHT,sdl.WINDOW_BORDERLESS)
    if window==nil{
        log_error("Error creating SDL window")
        return false
    }
    //intializing drawing_buffer
    drawing_buffer = make([]u32,WINDOW_WIDTH*WINDOW_HEIGHT)
    clear_buffer(drawing_buffer,0xFF000000)
    //initialzing renderer
    renderer = sdl.CreateRenderer(window,-1,nil)
    if renderer==nil{
        log_error("Error creating a renderer")
        return false
    }
    return true
}

main :: proc(){
    log_info("Starting the application")
    is_window_running = initialize_window()
    stack_init(&Line_Stack)
    stack_init(&Undo_Stack)  
    defer stack_free(&Line_Stack)
    defer stack_free(&Undo_Stack)
    defer sdl.DestroyRenderer(renderer)
    defer sdl.DestroyWindow(window)
    defer sdl.Quit()

    setup()

    for is_window_running!=false{
        check_input()
        update_window()
        render_window()
    }
}