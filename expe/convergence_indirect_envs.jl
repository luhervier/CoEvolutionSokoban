using Cambrian
using EvolutionaryStrategies
using Flux
using Statistics
using Random
using Formatting
using CSV
using DataFrames
using ProgressBars
using Logging
using Distances
import Cambrian: mutate, crossover, populate, save_gen, generation, ga_populate, step!, log_gen
import EvolutionaryStrategies: snes_populate, snes_generation

include("../src/continuous_sokolvl.jl")
include("../src/utils.jl")
#-----------------------------Configuration-----------------------------#
cfg_envs = Cambrian.get_config("cfg/sokoevo_continuous_envs.yaml")

# envs_model = Chain(
#                     Dense(2,16),
#                     Dense(16,32),
#                     Dense(32,16),
#                     Dense(16,5),
#                     softmax
#                     )

envs_model = Chain(
                    Dense(6,16),
                    Dense(16,32),
                    Dense(32,16),
                    Dense(16,5),
                    softmax
                    )
expe_name = "indirectenvs_convergence"
# Overrides of the mutate function
mutate(i::ContinuousSokoLvl) = mutate(i, cfg_envs.p_mutation)

selection(pop::Array{<:Individual}) = Cambrian.tournament_selection(pop, cfg_envs.tournament_size)
#----------------------------------sNES Helpers--------------------------------#
populate(e::sNES{ContinuousSokoLvl}) = snes_populate(e)
generation(e::sNES{ContinuousSokoLvl}) = snes_generation(e)

ref_lvl_str = "wwwwwwww\nw.....ww\n..bwbhww\n.w.b..ww\nA.b.whww\n..whb.ww\nw.h..hww\nwwwwwwww\n"

width = cfg_envs.width
height = cfg_envs.height
objects_char_list = cfg_envs.objects_char_list
depth = length(objects_char_list)
map_objects = Dict( objects_char_list[i] => i for i in 1:depth)
#--------------------------------Evaluate helper-------------------------------#
function from_str_to_bit(lvl_str::String)
    bit_array = fill(false,width,height,depth)
    for y_pos in 1:height
        for x_pos in 1:width
            pos_in_list = x_pos + (y_pos-1)*(width + 1)
            char = "$(lvl_str[pos_in_list])"
            layer = map_objects[char]
            bit_array[y_pos,x_pos,layer] = true
        end
    end
    return BitArray(bit_array)
end

ref_bit = from_str_to_bit(ref_lvl_str)

function fitness_env(env::ContinuousSokoLvl)
    apply_continuoussokolvl_genes!(env)
    lvl_str = write_map2!(env)
    lvl_bit = from_str_to_bit(lvl_str)
    return [-hamming(ref_bit,lvl_bit)/2]
end

function evaluate(e::AbstractEvolution)
    for i in eachindex(e.population)
        e.population[i].fitness[:] = e.fitness(e.population[i])
    end
end

function log_gen(e::AbstractEvolution)
    for d in 1:e.config.d_fitness
        maxs = map(i->i.fitness[d], e.population)
        with_logger(e.logger) do
            @info Formatting.format("{1:05d},{2:e},{3:e},{4:e}",
                                    e.gen, maximum(maxs), mean(maxs), std(maxs))
        end
    end
    flush(e.logger.stream)
end

# overrides save_gen for sNES population
function save_gen(e::sNES{ContinuousSokoLvl})
    path = Formatting.format("gens/$expe_name/{1:05d}", e.gen)
    mkpath(path)
    sort!(e.population)
    for i in eachindex(e.population)
        path_ind = Formatting.format("{1}/{2:04d}.dna", path, i)
        save_ind(e.population[i],path_ind)
    end
end

function step!(e::sNES{ContinuousSokoLvl})
    e.gen += 1

    if e.gen > 1
        populate(e)
    end

    evaluate(e)
    generation(e)

    if ((e.config.log_gen > 0) && mod(e.gen, e.config.log_gen) == 0)
        log_gen(e)
    end
end

# overrides run! to add saving options
function run!(e::sNES{ContinuousSokoLvl})
    best_gen_fitness = -Inf
    e_best = deepcopy(e)
    for i in tqdm((e.gen+1):e.config.n_gen)
        step!(e)
        best_env = sort(e.population)[end]
        if best_env.fitness[1] > best_gen_fitness
            best_gen_fitness = best_env.fitness[1]
            e_best = deepcopy(e)
        end
    end
    save_gen(e_best)
end
#------------------------------------Main------------------------------------#
envs = sNES{ContinuousSokoLvl}(envs_model,cfg_envs,fitness_env;logfile=string("logs//","$expe_name//$expe_name", ".csv"))

run!(envs)

best_env = sort(envs.population)[end]
println("Final fitness envs: ", best_env.fitness[1])
