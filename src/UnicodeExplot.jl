module UnicodeExplot

export lineplotex

using UnicodePlots
using TextUserInterfaces

mutable struct PlotWidget <: Widget
   parent::Window
   cwin::Ptr{WINDOW}
   update_needed::Bool

   plot
end



function PlotWidget(parent::Window, nlines::Int, ncols::Int, plot)
    # Create the window that will hold the contents.
    cwin = subpad(parent.buffer, nlines, ncols, 0, 0)

    widget = PlotWidget(parent, cwin, false, plot)
    push!(parent.widgets, widget)

    return widget
end


# Redraw event.
function TextUserInterfaces.redraw(widget::PlotWidget)
    cwin = widget.cwin
    wclear(cwin)

    c = ncurses_color(bold = true)

    plot = widget.plot

    wattron(cwin, c)
    mvwprintw(cwin, 0, 0, plot |> string)
    wattroff(cwin, c)

    return nothing
end


function lineplotex(fn::Function, x0, x1;
                    ylim=(0, 0), width=0, height=0, kwargs...)
    init_tui()
    try
        margin = 30
        if width == 0
            width = COLS()-margin
        end
        if height == 0
            height = min(30, LINES())-5
        end
        plot = lineplot(fn, x0, x1;
                        ylim=ylim, xlim=[x0, x1], width=width, height=height,
                        kwargs...)
        numcols = ncols(plot.graphics)+margin
        nlines = nrows(plot.graphics)+5

        if ylim == (0, 0)
            ylim = origin_y(plot.graphics)
            ylim = [ylim, ylim + UnicodePlots.height(plot.graphics)]
        end

        noecho()
        win = create_window(nlines, numcols, 0, 0; border = false, title="test")
        plotwidget = PlotWidget(win, nlines, numcols, plot)
        #focus_on_widget(plotwidget)

        # Initialize the focus manager.
        tui.focus_chain = [win]
        init_focus_manager()

        # Initial painting.
        request_update(plotwidget)
        refresh_all_windows()
        update_panels()

        doupdate()

        k = jlgetch()

        while (k.ktype != :F1)
            #process_focus(k)

            update = false
            if k.ktype in [:left, :right]
                step = (x1 - x0) / 5
                if k.ktype == :left
                    step *= -1
                end
                if k.shift
                    x0 += step
                    x1 -= step
                else
                    x0 += step
                    x1 += step
                end

                update = true
            elseif k.ktype in [:up, :down]
                step = (ylim[2] - ylim[1]) / 5
                if k.ktype == :down
                    step *= -1
                end
                if k.shift
                    ylim[1] += step
                    ylim[2] -= step
                    x0 += step
                    x1 -= step
                else
                    ylim[1] += step
                    ylim[2] += step
                end
                ylim = round.(ylim; sigdigits = 2)
                update = true
            end

            # Update if necessary because of focus change.
            if update
                plotwidget.plot = lineplot(fn, x0, x1;
                    ylim=ylim, xlim=[x0, x1], width=width, height=height, kwargs...)
                request_update(plotwidget)
                refresh_all_windows()
                update_panels()

                doupdate()
            end

            k = jlgetch()
        end
    finally
        destroy_tui()
    end
end

end # module
