"""
    autorun(eff)

special effectrunner which recognizes effecttypes used within `eff` and calls the effects in order, such that the
first effect found will at the end be the most outer container, and the last different effect found will be the most
inner container of the result value.
"""
autorun(eff::Eff) = runlast_ifpossible(_autorun((), eff))
function _autorun(handlers, eff::Eff)
  # for autorun we only deal with simple handlers `handler = typeof(eff.value)` where `eff_applies(handler, eff.value)`
  handler = eff_autohandler(eff.value)

  if handler ∈ handlers || !eff_applies(handler, eff.value)
    # If we encounter a handler which we already triggered, we don't want to trigger it again, however
    # we need to make sure that subsequent unseen handlers will be triggered correctly.
    # Hence, we build a continuation with calling `_autorun`.

    # The same we want to happen if we found a handler which cannot be handled automatically.
    # We just skip it and leave it for later handling.
    if isempty(eff.cont)
      eff
    else
      Eff(eff.value, Continuation(x -> _autorun(handlers, eff.cont(x))))
    end
  else
    # If this is a new valid handler, we trigger standard handler interpretation, with the one difference, that before
    # recursing into runhandler on the interpreted_continuation, we want to handle all yet unseen nested handlers.
    # We do this by first calling `_autorun` before calling `runhandler` within the interpreted_continuation.
    handlers_new = (handler, handlers...)
    interpreted_continuation = if isempty(eff.cont)
      Continuation(x -> _eff_pure(handler, x))
    else
      Continuation(x -> runhandler(handler, _autorun(handlers_new, eff.cont(x))))
    end
    _eff_flatmap(handler, interpreted_continuation, eff.value)
  end
end

"""
    eff_autohandler(value) = typeof(value).name.wrapper

Overwrite this if the default autohandler extraction does not work for your case.
E.g. for ``value::Vector`` the default would return `Array`, hence we need to overwrite it individually.
"""
eff_autohandler(value) = typeof(value).name.wrapper
