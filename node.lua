util.init_hosted()

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local json = require "json"
local posts = {}
local post_images = {}
local overlay = resource.load_image('overlay.png')
local current_post = 1
local last_change = 0

util.resource_loader{
    "crossfade.frag";
}

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

function node.render()
    CONFIG.background.clear()

    if last_change+10 < sys.now() then
        current_post = current_post+1
        last_change = sys.now()

        if #posts < current_post then
            current_post = 1
        end
    end

    post = posts[current_post]

    if post.image and post_images[post.postId] then
        state, width, height = post_images[post.postId]:state()

        if state == 'loaded' then
            posx = (NATIVE_WIDTH-width)/2
            posy = (NATIVE_HEIGHT-height)/2

            post_images[post.postId]:draw(posx, posy, posx+width, posy+height)
        end
    end


    size = 70
    while CONFIG.font:width(post.title, size) > NATIVE_WIDTH-200 do
        size = size - 2
    end
    posy = NATIVE_HEIGHT-200

    overlay:draw(0,posy,NATIVE_WIDTH,NATIVE_HEIGHT)

    CONFIG.font:write(100, posy+20, post.kicker, 30, 255,255,255,1)

    line = ''
    for word in post.title:gmatch("%S+") do
        line_tmp = trim(line..' '..word)

        text_width = CONFIG.font:width(line_tmp, 70)
        if text_width > NATIVE_WIDTH-200 then
            line = line..' ...'
            break
        else
            line = line_tmp
        end
    end

    CONFIG.font:write(100, posy+60, line, 70, 255,255,255,1)

    --[[ excerpt
    excerpt_split = post.excerpt:gmatch("%S+")
    line = ''
    posy = posy+150

    for word in excerpt_split do
        if posy > NATIVE_HEIGHT-40 then
            break
        end

        line_tmp = line..' '..word

        text_width = CONFIG.font:width(line_tmp, 30)
        if text_width > NATIVE_WIDTH-200 then
            CONFIG.font:write(100, posy, trim(line), 30, 255,255,255,1)

            line = word
            posy = posy+40
        else
            line = line_tmp
        end
    end ]]



    CONFIG.font:write(5, NATIVE_HEIGHT-25, post.creator..' - '..post.likes..' likes, '..post.comments..' comments', 20, 255,255,255,1)

    text = 'Content from '..CONFIG.base_url
    text_width = CONFIG.font:width(text, 20)
    CONFIG.font:write(NATIVE_WIDTH-text_width-5, NATIVE_HEIGHT-25, text, 20, 255,255,255,1)
end
