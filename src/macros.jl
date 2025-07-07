"""
Registers the name of a voting method when it's assigned.
"""
macro namevm(assignment)
    eval(assignment)
    vmnames[eval(assignment.args[2])] = String(assignment.args[1])
end

macro namestrat(assignment)
    eval(assignment)
    stratnames[eval(assignment.args[2])] = String(assignment.args[1])
end

macro nameistrat(assignment)
    eval(assignment)
    istrat_names[eval(assignment.args[2])] = String(assignment.args[1])
end

macro nameselector(assignment)
    eval(assignment)
    selector_names[eval(assignment.args[2])] = String(assignment.args[1])
end