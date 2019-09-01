module TestNotifications

  DIALOG_SAMPLES = {
    table: [
      {
        text: "<b>Register</b> to save your progress!"
      },
      {
        input: {
          type: "text",
          name: "someValue",
          title: "Some Value",
          maxlength: 32,
          value: "Default Value",
          error: "Your value is invalid"
        }
      },
      {
        input: {
          type: "select",
          name: "selectValue",
          title: "Select Value",
          options: [
            { label: "One", value: "one" },
            { color: "ff3322", value: "reddish" },
            { sprite: "heart", value: "heart" }
          ],
          value: "reddish"
        }
      },
      {
        input: {
          type: "slider",
          name: "numericValue",
          title: "Numeric Value",
          min: 5,
          max: 15,
          step: 2,
          value: 10
        }
      },
      {
        input: {
          type: "checkbox",
          name: "boolValue",
          title: "Bool Value",
          value: true
        }
      },
      {
        prefab: "MiscPrefab"
      }
    ],
    actions: [
      { title: "Cancel", event: "dialogCancelled" },
      { title: "Okay", command: "myDialog", sprite: "commandButton" }
    ]
  }


end