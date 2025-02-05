package main
import "core:fmt"
import "core:time"
import sdl "vendor:sdl2"

log_types::enum{
    INFO,
    WARN,
    ERROR
}
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
is_drawing:bool =false

is_window_running:bool = false
renderer:^sdl.Renderer = nil
window : ^sdl.Window = nil
color_buffer:[WINDOW_HEIGHT][WINDOW_WIDTH]u32
color_buffer_texture: ^sdl.Texture = nil
drawing_buffer:[]u32
is_d_pressed:bool = false

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
id_of_current_line:u128=0
Line_Data::struct{
    line_start:struct{x:f32,y:f32},
    line_end:struct{x:f32,y:f32},
    thickness:u32
}
Fill_Data::struct{
    initialization_point:struct{x:f32, y:f32},
    color_to_be_replaced:u32
}
Drawing_Type::enum{
    LINE,
    FILL
}
Line::struct{
    data:union{
        Line_Data,
        Fill_Data
    },
    drawing_type:Drawing_Type,
    color:u32,
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
                color:=d.color
                thickness:=line_data.thickness
                x_start,y_start:=line_data.line_start.x,line_data.line_start.y
                x_end,y_end:=line_data.line_end.x,line_data.line_end.y
                draw_line(i32(x_start),i32(y_start),i32(x_end),i32(y_end),color)
            }
            case .FILL:{

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
catch_perimeter_points_of_the_area_to_be_filled::proc(x:f32,y:f32,color:u32,existing_color_to_be_replaced:u32){
    if x>0 && y>0 && x<WINDOW_WIDTH && y<WINDOW_HEIGHT && drawing_buffer[WINDOW_WIDTH * int(y) + int(x)]!=color && drawing_buffer[WINDOW_WIDTH * int(y) + int(x)]==existing_color_to_be_replaced{
        draw_pixel(i32(x),i32(y),color)
        catch_perimeter_points_of_the_area_to_be_filled(x+1,y,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x+1,y+1,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x,y+1,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x-1,y,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x-1,y-1,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x,y-1,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x+1,y-1,color,existing_color_to_be_replaced)
        catch_perimeter_points_of_the_area_to_be_filled(x-1,y+1,color,existing_color_to_be_replaced)
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
                    case .R:
                        perform_empty_check_and_swap_lines_among_stacks(&Line_Stack,&Undo_Stack)
                    case .F:
                        // mouse_event := cast(^sdl.MouseMotionEvent)&event
                        // current_mouse_pos := vec2_t{f32(mouse_event.x), f32(mouse_event.y)}
                        // log_info("Caught mouse motion at",current_mouse_pos.x,current_mouse_pos.y)
                        // color_to_be_filled:u32 = 0xFF00FF00
                        // existing_pixel_color_to_be_replaced:u32 = drawing_buffer[WINDOW_WIDTH * int(current_mouse_pos.y) + int(current_mouse_pos.x)] //We will be replacing pixel color that the mouse is at
                        // Current_Filled_Area:Filled_Area
                        // Current_Filled_Area.color_filled_with = color_to_be_filled
                        // Current_Filled_Area.perimeter_points=make([dynamic]vec2_t)
                        // catch_perimeter_points_of_the_area_to_be_filled(current_mouse_pos.x,current_mouse_pos.y,color_to_be_filled,existing_pixel_color_to_be_replaced,&Current_Filled_Area)
                        // //putting these perimeter points onto Filled_Area Stack which we will populate while drawing the buffer
                        // stack_push(&Filled_Area_Stack,Current_Filled_Area)
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
                }
            case .MOUSEMOTION:
                mouse_event := cast(^sdl.MouseMotionEvent)&event
                current_mouse_pos := vec2_t{f32(mouse_event.x), f32(mouse_event.y)}
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
                        },
                        Drawing_Type.LINE,
                        0xFF0000FF,
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
draw_line :: proc(x0, y0, x1, y1: i32, color: u32) {
    x := x0
    y := y0

    dx := abs(x1 - x0)
    dy := abs(y1 - y0)
    sx :i32= x0 < x1 ? 1 : -1
    sy :i32= y0 < y1 ? 1 : -1
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

draw_fat_pixel :: proc(x:i32,y:i32,color:u32){
    for y_index:=y;y_index<y+2;y_index+=1{
        for x_index:=x;x_index<x+2;x_index+=1{
            draw_pixel(x_index,y_index,color)
        }
    }
}

draw_pixel :: proc(x: i32, y: i32, color: u32) {
    if x >= 0 && x < WINDOW_WIDTH && y >= 0 && y < WINDOW_HEIGHT {
        drawing_buffer[WINDOW_WIDTH * int(y) + int(x)] = color
    }
}

draw_rect :: proc(x, y, width, height: i32, color: u32){
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
    clear_color_buffer(0xFF000000)  // Clear temporary buffer
    //both drawing line and filling area is done on the drawing_buffer
    draw_line_from_stack(&Line_Stack)
    render_color_buffer()           // Copy drawing buffer to color buffer
    draw_grid()                     // Draw grid ON TOP of existing drawing
    // Update texture with COMBINED content (drawing + grid)
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
    window = sdl.CreateWindow("Test Application",sdl.WINDOWPOS_CENTERED,sdl.WINDOWPOS_CENTERED,WINDOW_WIDTH,WINDOW_HEIGHT,sdl.WINDOW_BORDERLESS)
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