angular.module('loomioApp').factory 'RecordStore', () ->
  class RecordStore
    constructor: (db) ->
      @db = db
      @collectionNames = []

    addRecordsInterface: (recordsInterfaceClass) ->
      recordsInterface = new recordsInterfaceClass(@)
      name = recordsInterface.model.plural
      @[_.camelCase(name)] = recordsInterface
      @collectionNames.push name

    import: (data) ->
      _.each @collectionNames, (name) =>
        if data[name]?
          _.each data[name], (record_data) =>
            @[_.camelCase(name)].initialize(record_data)
      data
