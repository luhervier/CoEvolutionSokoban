"SokoLvlIndividual : Individual class using a binary string genotype"
struct SokoLvlIndividual <: Cambrian.Individual
    genes::BitArray
    fitness::Array{Float64}
    width::Int64
    height::Int64
    objects_char_list::Array{String}
    agent_idx::Int64
end

function SokoLvlIndividual(width::Int64,height::Int64,objects_char_list::Array{String},agent_idx::Int64)::SokoLvlIndividual
    nb_object = length(objects_char_list)
    SokoLvlIndividual(BitArray(rand(Bool,nb_object*width*height)), -Inf*ones(1),width,height,objects_char_list,agent_idx)
end

function SokoLvlIndividual(cfg::NamedTuple)::SokoLvlIndividual
    width = cfg.width
    height = cfg.height
    objects_char_list = cfg.objects_char_list
    agent_idx = cfg.agent_idx
    nb_object = length(objects_char_list)
    SokoLvlIndividual(BitArray(rand(Bool,nb_object*width*height)), -Inf*ones(cfg.d_fitness),width,height,objects_char_list,agent_idx)
end

function SokoLvlIndividual(genes::BitArray, cfg::NamedTuple)::SokoLvlIndividual
    width = cfg.width
    height = cfg.height
    objects_char_list = cfg.objects_char_list
    agent_idx = cfg.agent_idx
    nb_object = length(objects_char_list)
    if length(genes) == width*height*nb_object
        SokoLvlIndividual(genes, -Inf*ones(cfg.d_fitness),width,height,objects_char_list,agent_idx)
    else
        throw("The genes you provided doesn't match the width, height and number of object for this SokoLvlIndividual configuration")
    end
end

function SokoLvlIndividual(cfg::NamedTuple, ind::String)::SokoLvlIndividual
    dict = JSON.parse(ind)
    SokoLvlIndividual(BitArray(dict["genes"]),cfg)
end

"""
mutate(parent::SokoLvlIndividual, m_rate::Float64). To use, define
    mutate(parent::SokoLvlIndividual) = mutate(parent, m_rate) with configured m_rate
for a Boolean individual, this random flips the bits of the parent
"""
function mutate(parent::SokoLvlIndividual, m_rate::Float64)
    inds = rand(length(parent.genes)) .<= m_rate
    genes = xor.(inds, parent.genes)
    get_child(parent, genes)
end

function transcript_sokolvl_genes(sokolvl_ind::SokoLvlIndividual)
    width = sokolvl_ind.width
    height = sokolvl_ind.height
    objects_char_list = sokolvl_ind.objects_char_list
    nb_object = length(objects_char_list)
    lvl_str = """"""
    for y_pos in 1:height
        for x_pos in 1:width
            object_in_x_y = "."
            for i in 1:nb_object
                if sokolvl_ind.genes[x_pos + (y_pos-1)*width + height*width*(i-1)] == 1
                    object_in_x_y = objects_char_list[i]
                end
            end
            lvl_str = string(lvl_str,object_in_x_y)
        end
        lvl_str = string(lvl_str,"\n")
    end
    return lvl_str
end

function apply_sokolvl_constraint!(sokolvl_ind)
    width = sokolvl_ind.width
    height = sokolvl_ind.height
    objects_char_list = sokolvl_ind.objects_char_list
    agent_idx = sokolvl_ind.agent_idx
    # step to ensure there is one and only one agent
    nb_agent_count = 0
    pos_agent = []
    pos_final_agent = 0
    for pos in 1:width*height
        if sokolvl_ind.genes[pos + (agent_idx-1)*width*height] == 1
            nb_agent_count += 1
            push!(pos_agent,pos)
        end
    end
    if nb_agent_count == 0
        pos_to_flip = rand(1:width*height)
        sokolvl_ind.genes[pos_to_flip + (agent_idx-1)*width*height] = 1
        pos_final_agent = pos_to_flip
    elseif nb_agent_count > 1
        pos_agent_to_keep = pos_agent[rand(1:nb_agent_count)]
        for pos in pos_agent
            sokolvl_ind.genes[pos + (agent_idx-1)*width*height] = 0
        end
        sokolvl_ind.genes[pos_agent_to_keep + (agent_idx-1)*width*height] = 1
        pos_final_agent = pos_agent_to_keep
    else
        # only one element in pos agent
        pos_final_agent = pos_agent[1]
    end

    # Now we ensure that there is no two similar tiles in a same position
    # we only need to work with non agent object
    non_agent_object_idx = [i for i in 1:length(objects_char_list)]
    deleteat!(non_agent_object_idx,agent_idx)

    for pos in 1:width*height
        # all object at the agent position flip bit to zero
        if pos==pos_final_agent
            for object_idx in non_agent_object_idx
                sokolvl_ind.genes[pos + (object_idx-1)*width*height] = 0
            end
        else
            # we reference all object at pos and if we have more than one
            # we keep randomly only one of them
            nb_object_at_pos = 0
            object_idx_at_pos = []
            for object_idx in non_agent_object_idx
                if sokolvl_ind.genes[pos + (object_idx-1)*width*height] == 1
                    nb_object_at_pos += 1
                    push!(object_idx_at_pos,object_idx)
                end
            end
            if nb_object_at_pos>1
                object_idx_to_keep = object_idx_at_pos[rand(1:nb_object_at_pos)]
                for object_idx in object_idx_at_pos
                    sokolvl_ind.genes[pos + (object_idx-1)*width*height] = 0
                end
                sokolvl_ind.genes[pos + (object_idx_to_keep-1)*width*height] = 1
            end
        end
    end
end