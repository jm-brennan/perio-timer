using Gtk;

namespace PatternTimer.Widgets {

    public class MainPopover : Budgie.Popover {
        private Stack? stack = null;
        private StackSwitcher? stackSwitcher = null;
        //private Notebook? notebook = null;
        private Box? mainView = null;
        private Box? header = null;
        private Label? headerLabel = null;
        private Button? headerNew_b = null;
        private PTimer[] timers = new PTimer[3];
        private int currentTimer = 0;
        private int numTimers = 1;

        public MainPopover(Widget? window_parent, int width, int height) {
            Object(relative_to: window_parent);
            this.set_resizable(false);
            // dont think that the outer popover needs to set size requests,
            // should just be determined by child elements? unclear
            //this.set_size_request(width, height);
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);
            add_events(Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
            
            mainView = new Box(Orientation.VERTICAL, 0);
            mainView.set_homogeneous(false);

            header = new Box(Orientation.HORIZONTAL, 0);
            header.height_request = 10;
            //Header.get_style_context().add_class("trash-applet-header");
            headerLabel = new Label("'Perio?' Timer!");
            
            header.pack_start(headerLabel, false, false, 0);
            headerNew_b = new Button.from_icon_name("list-add-symbolic", IconSize.MENU);
            headerNew_b.clicked.connect(() => {
                if (numTimers == 3) {
                    return;
                } else {
                    timers[currentTimer].set_inactive();
                    numTimers++;
                    currentTimer = numTimers - 1;
                    /*  if (currentTimer == 1) {
                        var ssBox = new Box(Orientation.HORIZONTAL, 0);
                        ssBox.pack_start(stackSwitcher, true, true);
                        mainView.pack_start(ssBox, true, true, 0);
                        mainView.reorder_child(ssBox, 1);
                    }  */
                    timers[currentTimer] = new PTimer(width, height, 1);
                    stack.add_titled(timers[currentTimer].timer_view(), currentTimer.to_string(), currentTimer.to_string());
                    mainView.show_all();
                    stack.set_visible_child_name(currentTimer.to_string());
                }
            });
            header.pack_end(headerNew_b, false, false, 0);
            mainView.pack_start(header, false, false, 0);

            stack = new Stack();
            stack.set_transition_type(StackTransitionType.SLIDE_LEFT_RIGHT);
            stackSwitcher = new StackSwitcher();
            stackSwitcher.stack = stack;
            stackSwitcher.set_homogeneous(true);
            stack.notify["visible-child"].connect(() => {
                string visibleChildName = stack.get_visible_child_name();
                if (visibleChildName == null) { // don't think this ever happens
                    visibleChildName = "0";
                }
                currentTimer = int.parse(visibleChildName);
            });

            timers[0] = new PTimer(width, height, 0);
            stack.add_titled(timers[0].timer_view(), currentTimer.to_string(), "Untitled Timer");
            mainView.pack_start(stackSwitcher, true, true, 0);

            mainView.pack_start(stack, false, false, 0);
            mainView.show_all();
            add(mainView);
        }

        public override bool key_press_event (Gdk.EventKey event) {
            //print(event.keyval.to_string());
            //print("\n");
            //print(this.get_focus());:
            if (this.get_focus() == timers[currentTimer].te) {
                print("text entry");
            }
            switch (event.keyval) {
                case KeyCode.ENTER:
                    timers[currentTimer].set_active();
                    break;
                case KeyCode.SPACE:
                    timers[currentTimer].toggle_active();
                    break;
                case KeyCode.BACK:
                    timers[currentTimer].im.backspace();
                    break;
                default:
                    timers[currentTimer].im.send_key(event.keyval, event.str);
                    break;
            }
            return Gdk.EVENT_PROPAGATE;
        }
    } // End class
} // End namespace