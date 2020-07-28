using Gtk;

namespace PerioTimer.Widgets {

public class PTimer {
    private Overlay? overlay = null;
    private TimerAnimation? ta = null;
    public InputManager? im = null;
    private Box? timerView = null;
    private Stack stageStack = null;
    private Box? stageLabels = null;
    private Box? settingsView = null;
    private bool started = false;
    private bool restarted = false;
    private int updateInterval = 10;
    private int timeToRepeat = 2000;
    private int timeToSwitchStage = 1000;
    
    private bool doSeconds = false;

    // @TODO load defaults from settings
    // button setup for timer behavior settings:
    // repeat: default off
    // notification: default on
    // volume: default on
    private ToggleButton repeatBut = null;
    private Image repeatImOn = new Image.from_icon_name("media-playlist-repeat-symbolic", IconSize.MENU);
    private Image repeatImOff = new Image.from_icon_name("media-playlist-consecutive-symbolic", IconSize.MENU);

    private ToggleButton notificationBut = null;
    private Image notificationImOn = new Image.from_icon_name("notification-alert-symbolic", IconSize.MENU);
    private Image notificationImOff = new Image.from_icon_name("notification-disabled-symbolic", IconSize.MENU);

    private ToggleButton volumeBut = null;
    private Image volumeImOn = new Image.from_icon_name("audio-volume-high-symbolic", IconSize.MENU);
    private Image volumeImOff = new Image.from_icon_name("audio-volume-muted-symbolic", IconSize.MENU);


    // @TODO testing hvaing a text box, need to figure out input redirection
    // public Entry te = null;

    // @TODO figuring out the multi stage stuff
    private const int MAX_STAGES = 4;
    private Stage[] stages = new Stage[MAX_STAGES];
    private int currentStage = 0;
    private int numStages = 1;
    private GLib.Queue<int> stageColors = new GLib.Queue<int>();

    public PTimer(int width, int height, int colorset, MainPopover parent) {
        im = new InputManager(this, parent);

        stageColors.push_head(3);
        stageColors.push_head(2);
        stageColors.push_head(1);
        stageColors.push_head(0);
        
        timerView = new Box(Orientation.VERTICAL, 0);
        // @TODO input redirection
        //timerView.set_focus_on_click(true);
        
        overlay = new Overlay();
        overlay.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        overlay.set_size_request(width, height);
        overlay.button_press_event.connect((e) => {
            this.toggle_active();
            return true;
        });
        // @TODO implement dragging leading edge of animation with this
        /*  overlay.button_release_event.connect((e) => {
            print("RELEASE\n");
            print(e.x.to_string());
            print("\n");
            print(e.y.to_string());
            return true;
        });
        overlay.leave_notify_event.connect(() => {
            print("LEFT");
            return true;
        });  */
        
        
        stages[0] = new Stage(stageColors.pop_head(), doSeconds);
        stageStack = new Stack();
        stageStack.set_transition_type(StackTransitionType.SLIDE_LEFT_RIGHT);
        stageStack.add(stages[0].get_view());
        stageStack.set_visible_child(stages[0].get_view());
        overlay.add(stageStack);

        ta = new TimerAnimation(width, height, stages);
        overlay.add_overlay(ta);
        timerView.pack_start(overlay, false, false, 0);
        
        stageLabels = new Box(Orientation.HORIZONTAL, 0);
        stageLabels.height_request = 20;
        stageLabels.set_halign(Align.CENTER);
        stageLabels.set_spacing(10);
        timerView.pack_start(stageLabels, true, true, 0);
        
        // @TODO text entry for timer names? gotta figure out input redirection
        // te = new Entry();
        // timerView.pack_start(te, false, false, 0);

        settingsView = new Box(Orientation.HORIZONTAL, 0);

        repeatBut = new ToggleButton();
        repeatBut.set_image(repeatImOff);
        repeatBut.clicked.connect(() => {
            if (repeatBut.get_active()) {
                repeatBut.set_image(repeatImOn);
            } else {
                repeatBut.set_image(repeatImOff);
            }
        });
        settingsView.pack_start(repeatBut, true, false, 0);

        volumeBut = new ToggleButton();
        volumeBut.set_image(volumeImOff);
        volumeBut.clicked.connect(() => {
            if (volumeBut.get_active()) {
                volumeBut.set_image(volumeImOn);
            } else {
                volumeBut.set_image(volumeImOff);
            }
        });
        settingsView.pack_start(volumeBut, true, false, 0);

        notificationBut = new ToggleButton();
        notificationBut.set_image(notificationImOff);
        notificationBut.clicked.connect(() => {
            if (notificationBut.get_active()) {
                notificationBut.set_image(notificationImOn);
            } else {
                notificationBut.set_image(notificationImOff);
            }
        });
        settingsView.pack_start(notificationBut, true, false, 0);

        timerView.pack_start(settingsView, true, true, 10);
    }

    public void set_input_time(string inputString) {
        stages[currentStage].set_smh(inputString);
        ta.update_stages(numStages);
    }

    public void start() {
        if (started || stages[currentStage].active) return;

        if (!restarted) add_label();

        currentStage = 0;
        stageStack.set_visible_child(stages[currentStage].get_view());
        started = true;

        // allows for proper editing of the stage when paused
        if (!doSeconds) {
            toggle_seconds();
            im.toggle_seconds();
        }
        set_active();
    }

    public void new_stage() {
        if (numStages == MAX_STAGES) return;
        
        add_label();
        started = false;

        // because the stageStack is an actual stack, can't just insert a new stage
        // into the middle of it. Have to pop off all the elements past the insertion
        // point and add them back on after making/adding the new stage
        GLib.Queue<int> stagesToReorder = new GLib.Queue<int>();
        for (int i = numStages; i > currentStage + 1; i--) {
            stages[i] = stages[i - 1];
            stagesToReorder.push_head(i);
            stageStack.remove(stages[i].get_view());
        }

        currentStage++;
        numStages++;

        stages[currentStage] = new Stage(stageColors.pop_head(), doSeconds);
        stageStack.add(stages[currentStage].get_view());

        while (stagesToReorder.get_length() != 0) {
            stageStack.add(stages[stagesToReorder.pop_head()].get_view());
        }
        
        ta.update_stages(numStages);
        timerView.show_all();
        stageStack.set_visible_child(stages[currentStage].get_view());
    }

    public void switch_stage_editing(int switchDirection, bool addLabel = true) {
        if (stages[currentStage].active) return;

        int prevStage = currentStage;
        int newStage = prevStage + switchDirection;
        if (newStage < 0 || newStage >= numStages) {
            newStage = prevStage;
        } else if (addLabel) {
            // it is a little wasteful to try to add it every time there is a switching of stages
            // but doing it with minimum checking would add too much complexity
            add_label();
        }
        // have to wait to assign to currentStage so that possible call to add_label will
        // have the stage we are switching from still set as the currentStage
        currentStage = newStage;

        im.set_inputString(stages[currentStage].inputString);
        stageStack.set_visible_child(stages[currentStage].get_view());
    }

    private void add_label() {
        var labels = stageLabels.get_children();
        for (int i = 0; i < labels.length(); i++) {
            if (stages[currentStage].labelBox == labels.nth_data(i)) return;
        }

        if (currentStage != 0 && stages[currentStage].labelDot == null) {
            stages[currentStage].labelDot = new Label("\u2022");
            stages[currentStage].labelBox.pack_start(stages[currentStage].labelDot, false, false, 0);
        }
        stages[currentStage].labelBox.pack_start(stages[currentStage].label, false, false, 0);
        stageLabels.pack_start(stages[currentStage].labelBox, false, false, 0);
        stageLabels.reorder_child(stages[currentStage].labelBox, currentStage);
        stageLabels.show_all();
    }

    private void remove_label() {
        var labels = stageLabels.get_children();
        for (int i = 0; i < labels.length(); i++) {
            if (stages[currentStage].labelBox == labels.nth_data(i)) {
                stageLabels.remove(stages[currentStage].labelBox);
                if (currentStage == 0 && numStages > 1 && stages[currentStage+1].labelDot != null) {
                    stages[currentStage+1].labelBox.remove(stages[currentStage+1].labelDot);
                    stages[currentStage+1].labelDot = null;
                }
            }
        }
        stageLabels.show_all();
    }

    public void toggle_active() {
        if (stages[currentStage].active) {
            set_inactive();
        } else if (started) {
            set_active();
        }
    }

    public void set_active() {
        if (!started) return;

        if (stageStack.get_visible_child() != stages[currentStage].get_view()) {
            stageStack.set_visible_child(stages[currentStage].get_view());
        }
        if (!stages[currentStage].active) {
            Timeout.add(0, update_time);
        }
        stages[currentStage].set_active();
        ta.set_active();
    }

    public void set_inactive() {
        if (!started) return;

        stages[currentStage].set_inactive();
        
        // set the inputString of the inputManager as though we had
        // typed out the timeLeft being display so it can be edited
        string s = stages[currentStage].string_from_timeLeft();
        stages[currentStage].inputString = s;
        im.set_inputString(s);
        
        ta.set_inactive();
    }

    // called by inputManager, does not change inputManager's doSeconds
    public void toggle_seconds() {
        if (stages[currentStage].active) return;

        // have to toggle doSeconds on all of them and update their text values
        // so that it will be correct when switching to view other stages
        doSeconds = !doSeconds;
        for (int i = 0; i < numStages; i++) {
            stages[i].doSeconds = doSeconds;
            stages[i].update_display();
        }
    }

    public void reset_timer() {
        started = false;
        restarted = true;
        for (int i = 0; i < numStages; i++) {
            stages[i].reset();
        }
        currentStage = 0;
        stageStack.set_visible_child(stages[currentStage].get_view());
        ta.update_stages(numStages);
    }

    public void delete_stage() {
        if (stages[currentStage].active) return;

        remove_label();
        stageColors.push_head(stages[currentStage].color);
        stageStack.remove(stages[currentStage].get_view());
        started = false;

        if (numStages == 1) {
            stages[currentStage] = new Stage(stageColors.pop_head(), doSeconds);
            stageStack.add(stages[currentStage].get_view());
        } else {
            for (int i = currentStage; i < numStages - 1; i++) {
                stages[i] = stages[i + 1];
            }
            numStages--;
        }

        ta.update_stages(numStages);
        stageStack.show_all();
        switch_stage_editing(-1, false);
    }     
    
    private bool update_time() {
        if (!stages[currentStage].active) return false;

        updateInterval = stages[currentStage].update_time();
        stages[currentStage].update_display();

        if (updateInterval != -1) { 
            Timeout.add(updateInterval, update_time);
        } else {
            // timer has ended, now decide between switching stages, repeating timer,
            // or coming to true end
            set_inactive();

            if (currentStage < numStages - 1) {
                // increment before timeout so that play can be pressed before the timeout
                // executes and it'll work properly
                currentStage++;
                //stageStack.set_visible_child(stages[currentStage].get_view());
                Timeout.add(timeToSwitchStage, () => {
                    set_active();
                    return false;
                });
            } else if (repeatBut.get_active()) {
                reset_timer();
                Timeout.add(timeToRepeat, () => {
                    start();
                    return false;
                });
            } else {
                Timeout.add(timeToSwitchStage, () => {
                    reset_timer();
                    return false;
                });
            }
        }
        return false;
    }

    public void toggle_repeat() { repeatBut.set_active(!repeatBut.get_active()); }

    public void toggle_notification() { notificationBut.set_active(!notificationBut.get_active()); }

    public void toggle_volume() { volumeBut.set_active(!volumeBut.get_active()); }

    public Box get_view() { return this.timerView; }
}

} // end namespace