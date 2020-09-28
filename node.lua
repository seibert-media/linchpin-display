util.init_hosted()
hosted_init()
gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local json = require "json"
local posts = {}
local post_images = {}
local overlay = resource.load_image('overlay.png')
local current_post = 1
local last_change = 0
local white = resource.create_colored_texture(1,1,1)

crossfade = util.shader_loader("crossfade.frag")

util.file_watch("posts.json", function(content)
    posts = json.decode(content)

    for idx, post in ipairs(posts) do
        if post.image then
            if not post_images[post.postId] then
                post_images[post.postId] = resource.load_image('postImage-'..post.postId..'.png')
            end
        end
    end
end)

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function switcher(get_screens)
    local current_idx = 0
    local current
    local current_state

    local switch = sys.now()
    local switched = sys.now()

    local blend = 0.8
    local mode = "switch"

    local old_screen
    local current_screen

    local screens = get_screens()

    local function prepare()
        local now = sys.now()
        if now - switched > blend and mode == "switch" then
            if current_screen then
                current_screen:dispose()
            end
            if old_screen then
                old_screen:dispose()
            end
            current_screen = nil
            old_screen = nil
            mode = "show"
        elseif now > switch and mode == "show" then
            mode = "switch"
            switched = now

            -- snapshot old screen
            gl.clear(0.5, 0.5, 0.5, 0.0)
            if current then
                current.draw(current_state)
            end
            old_screen = resource.create_snapshot(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)

            -- find next screen
            current_idx = current_idx + 1
            if current_idx > #screens then
                screens = get_screens()
                current_idx = 1
            end
            current = screens[current_idx]
            switch = now + current.time
            current_state = current.prepare()

            -- snapshot next screen
            gl.clear(0.5, 0.5, 0.5, 0.0)
            current.draw(current_state)
            current_screen = resource.create_snapshot(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
        end
    end

    local function draw()
        local now = sys.now()
        local progress = ((now - switched) / (switch - switched))
        if mode == "switch" then
            local progress = (now - switched) / blend
            crossfade:use{
                Old = old_screen;
                progress = progress;
                one_minus_progress = 1 - progress;
            }
            current_screen:draw(0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
            crossfade:deactivate()
        else
            current.draw(current_state)
        end

        white:draw(0, NATIVE_HEIGHT-2, NATIVE_WIDTH * progress, NATIVE_HEIGHT, 0.3)
    end
    return {
        prepare = prepare;
        draw = draw;
    }
end

local content = switcher(function()
    local screens = {}
    local function add_screen(screen)
        screens[#screens+1] = screen
    end

    for idx,post in ipairs(posts) do
        add_screen({
            time = 10,
            prepare = function()
            end;
            draw = function()
                title_lines = {}
                index = 1
                for word in post.title:gmatch("%S+") do
                    if title_lines[index] == nil then
                        title_lines[index] = ''
                    end

                    line_tmp = trim(title_lines[index]..' '..word)

                    text_width = CONFIG.font:width(line_tmp, 70)
                    if text_width > NATIVE_WIDTH-200 then
                        index = index + 1
                        title_lines[index] = word
                    else
                        title_lines[index] = line_tmp
                    end
                end

                excerpt_lines = {}
                index = 1
                for word in post.excerpt:gmatch("%S+") do
                    if excerpt_lines[index] == nil then
                        excerpt_lines[index] = ''
                    end

                    line_tmp = trim(excerpt_lines[index]..' '..word)

                    text_width = CONFIG.font:width(line_tmp, 30)
                    if text_width > NATIVE_WIDTH-200 then
                        index = index + 1
                        excerpt_lines[index] = word
                    else
                        excerpt_lines[index] = line_tmp
                    end
                end

                if CONFIG.show_excerpt then
                    posy = NATIVE_HEIGHT-120-(80*#title_lines)-(40*#excerpt_lines)
                else
                    posy = NATIVE_HEIGHT-120-(80*#title_lines)
                end

                if post.image and post_images[post.postId] then
                    state, width, height = post_images[post.postId]:state()

                    if state == 'loaded' then
                        scale_factor_by_height = NATIVE_HEIGHT/height
                        scale_factor_by_width = NATIVE_WIDTH/width

                        if height*scale_factor_by_width > NATIVE_HEIGHT then
                            scale_factor = scale_factor_by_height
                        else
                            scale_factor = scale_factor_by_width
                        end

                        if scale_factor < 1 then
                            final_height = height*scale_factor
                            final_width = width*scale_factor
                        else
                            final_height = height
                            final_width = width
                        end

                        img_posx = (NATIVE_WIDTH-final_width)/2

                        if final_height < posy then
                            img_posy = (posy-final_height)/2
                        else
                            img_posy = 0
                        end

                        post_images[post.postId]:draw(img_posx, img_posy, img_posx+final_width, img_posy+final_height)
                    end
                end


                if string.len(post.kicker) > 0 then
                    overlay:draw(0,posy-40,NATIVE_WIDTH,NATIVE_HEIGHT)
                    CONFIG.font:write(100, posy, post.kicker, 30, 255,255,255,1)
                else
                    overlay:draw(0,posy,NATIVE_WIDTH,NATIVE_HEIGHT)
                end

                for i, line in ipairs(title_lines) do
                    CONFIG.font:write(100, posy-40+(80*i), line, 70, 255,255,255,1)
                end

                if CONFIG.show_excerpt then
                    for i, line in ipairs(excerpt_lines) do
                        CONFIG.font:write(100, posy+(80*#title_lines)+(40*i), line, 30, 255,255,255,1)
                    end
                end

                infoline = post.creator..' - '..post.date..' - '..post.likes..' like'

                if post.likes ~= 1 then
                    infoline = infoline..'s'
                end

                infoline = infoline..', '..post.comments..' commment'

                if post.comments ~= 1 then
                    infoline = infoline..'s'
                end

                CONFIG.font:write(100, NATIVE_HEIGHT-80, infoline, 20, 255,255,255,1)
            end
        })
    end
    return screens
end)

function node.render()
    content.prepare()
    gl.clear(0,0,0,1)

    local fov = math.atan2(NATIVE_HEIGHT, NATIVE_WIDTH*2) * 360 / math.pi
    gl.perspective(fov, NATIVE_WIDTH/2, NATIVE_HEIGHT/2, -NATIVE_WIDTH,
                        NATIVE_WIDTH/2, NATIVE_HEIGHT/2, 0)
    content.draw()

end
