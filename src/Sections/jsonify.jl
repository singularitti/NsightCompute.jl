using JSON3: JSON3

export jsonify

# A small helper to attempt parsing a string into a number (Int or Float).
# If it fails, it returns the original string, stripped of quotes if present.
function _parse_value(str::AbstractString)
    # Strip leading/trailing whitespace and surrounding quotes
    stripped = strip(str)
    if length(stripped) >= 2 && first(stripped) == '"' && last(stripped) == '"'
        return String(strip(stripped, '"'))
    end
    # Attempt to parse as an Integer
    int_val = tryparse(Int, stripped)
    if !isnothing(int_val)
        return int_val
    end
    # Attempt to parse as a Float
    float_val = tryparse(Float64, stripped)
    if !isnothing(float_val)
        return float_val
    end
    # Return the stripped string if it's not a number
    return String(stripped)
end

# Helper function to correctly add a value to a dictionary.
# If the key already exists, it converts the entry into a Vector
# to handle the "repeated keys become an array" rule.
function _dict_append!(dict::Dict{String,Any}, key::String, value::Any)
    if !haskey(dict, key)
        # Key doesn't exist, just add it.
        dict[key] = value
    else
        # Key already exists.
        current_value = dict[key]
        if current_value isa Vector
            # It's already a vector, just push the new value.
            push!(current_value, value)
        else
            # It's not a vector. Create one with the old and new values.
            dict[key] = [current_value, value]
        end
    end
end

function _parse_block(lines, index)
    result_dict = Dict{String,Any}()
    i = index
    while i <= length(lines)
        line = strip(lines[i])
        if isempty(line) || line == "{"
            i += 1
            continue
        end
        # End of the current block
        if line == "}"
            return result_dict, i + 1
        end
        # Match a nested object like `Key {`
        nested_match = match(r"^\s*([\w\d_]+)\s*\{", line)
        if !isnothing(nested_match)
            key = String(nested_match.captures[1])
            # Recursively parse the nested block
            nested_obj, next_i = _parse_block(lines, i + 1)
            _dict_append!(result_dict, key, nested_obj)
            i = next_i
            continue
        end
        # Match a simple key-value pair like `Key: "Value"`
        kv_match = match(r"^\s*([\w\d_]+):\s*(.*)", line)
        if !isnothing(kv_match)
            key = String(kv_match.captures[1])
            value_str = String(kv_match.captures[2])
            value = _parse_value(value_str)
            _dict_append!(result_dict, key, value)
            i += 1
            continue
        end
        # If we reach here, the line format is unexpected.
        # For robustness, we can print a warning and skip it.
        @warn "Skipping unrecognized line format at line $i: $(lines[i])"
        i += 1
    end
    return result_dict, i
end

function jsonify(str; pretty=true)
    lines = split(str, '\n')
    # Start parsing from the first line
    parsed_structure, _ = _parse_block(lines, 1)
    # Use JSON3 to serialize the resulting Julia Dict into a JSON string
    if pretty
        # JSON3.pretty requires an IO buffer
        buf = IOBuffer()
        JSON3.pretty(buf, parsed_structure)
        return String(take!(buf))
    else
        return JSON3.write(parsed_structure)
    end
end
