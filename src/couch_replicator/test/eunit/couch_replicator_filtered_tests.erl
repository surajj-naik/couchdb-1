% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(couch_replicator_filtered_tests).


-include_lib("couch/include/couch_eunit.hrl").
-include_lib("couch/include/couch_db.hrl").
-include_lib("couch_replicator/src/couch_replicator.hrl").
-include_lib("fabric/test/fabric2_test.hrl").


-define(DDOC, #{
    <<"_id">> => <<"_design/filter_ddoc">>,
    <<"filters">> => #{
        <<"testfilter">> => <<"
            function(doc, req){if (doc.class == 'mammal') return true;}
        ">>,
        <<"queryfilter">> => <<"
            function(doc, req) {
                if (doc.class && req.query.starts) {
                    return doc.class.indexOf(req.query.starts) === 0;
                }
                else {
                    return false;
                }
            }
        ">>
    },
    <<"views">> => #{
        <<"mammals">> => #{
            <<"map">> => <<"
                function(doc) {
                    if (doc.class == 'mammal') {
                        emit(doc._id, null);
                    }
                }
            ">>
        }
    }
}).


filtered_replication_test_() ->
    {
        "Replications with filters tests",
        {
            setup,
            fun couch_replicator_test_helper:start_couch/0,
            fun couch_replicator_test_helper:stop_couch/1,
            {
                foreach,
                fun setup/0,
                fun teardown/1,
                [
                    ?TDEF_FE(filtered_replication_test),
                    ?TDEF_FE(query_filtered_replication_test),
                    ?TDEF_FE(view_filtered_replication_test)
                ]
            }
        }
    }.


setup() ->
    Source = couch_replicator_test_helper:create_db(),
    create_docs(Source),
    Target = couch_replicator_test_helper:create_db(),
    {Source, Target}.


teardown({Source, Target}) ->
    couch_replicator_test_helper:delete_db(Source),
    couch_replicator_test_helper:delete_db(Target).


filtered_replication_test({Source, Target}) ->
    RepObject = {[
        {<<"source">>, Source},
        {<<"target">>, Target},
        {<<"filter">>, <<"filter_ddoc/testfilter">>}
    ]},
    {ok, _} = couch_replicator_test_helper:replicate(RepObject),
    FilterFun = fun(_DocId, {Props}) ->
        couch_util:get_value(<<"class">>, Props) == <<"mammal">>
    end,
    {ok, TargetDbInfo, AllReplies} = compare_dbs(Source, Target, FilterFun),
    ?assertEqual(1, proplists:get_value(doc_count, TargetDbInfo)),
    ?assertEqual(0, proplists:get_value(doc_del_count, TargetDbInfo)),
    ?assert(lists:all(fun(Valid) -> Valid end, AllReplies)).


query_filtered_replication_test({Source, Target}) ->
    RepObject = {[
        {<<"source">>, Source},
        {<<"target">>, Target},
        {<<"filter">>, <<"filter_ddoc/queryfilter">>},
        {<<"query_params">>, {[
            {<<"starts">>, <<"a">>}
        ]}}
    ]},
    {ok, _} = couch_replicator_test_helper:replicate(RepObject),
    FilterFun = fun(_DocId, {Props}) ->
        case couch_util:get_value(<<"class">>, Props) of
            <<"a", _/binary>> -> true;
            _ -> false
        end
    end,
    {ok, TargetDbInfo, AllReplies} = compare_dbs(Source, Target, FilterFun),
    ?assertEqual(2, proplists:get_value(doc_count, TargetDbInfo)),
    ?assertEqual(0, proplists:get_value(doc_del_count, TargetDbInfo)),
    ?assert(lists:all(fun(Valid) -> Valid end, AllReplies)).


view_filtered_replication_test({Source, Target}) ->
    RepObject = {[
        {<<"source">>, Source},
        {<<"target">>, Target},
        {<<"filter">>, <<"_view">>},
        {<<"query_params">>, {[
            {<<"view">>, <<"filter_ddoc/mammals">>}
        ]}}
    ]},
    {ok, _} = couch_replicator_test_helper:replicate(RepObject),
    FilterFun = fun(_DocId, {Props}) ->
        couch_util:get_value(<<"class">>, Props) == <<"mammal">>
    end,
    {ok, TargetDbInfo, AllReplies} = compare_dbs(Source, Target, FilterFun),
    ?assertEqual(1, proplists:get_value(doc_count, TargetDbInfo)),
    ?assertEqual(0, proplists:get_value(doc_del_count, TargetDbInfo)),
    ?assert(lists:all(fun(Valid) -> Valid end, AllReplies)).


compare_dbs(Source, Target, FilterFun) ->
    {ok, TargetDb} = fabric2_db:open(Target, [?ADMIN_CTX]),
    {ok, TargetDbInfo} = fabric2_db:get_db_info(TargetDb),
    Fun = fun(SrcDoc, TgtDoc, Acc) ->
        case FilterFun(SrcDoc#doc.id, SrcDoc#doc.body) of
            true -> [SrcDoc == TgtDoc | Acc];
            false -> [not_found == TgtDoc | Acc]
        end
    end,
    Res = couch_replicator_test_helper:compare_fold(Source, Target, Fun, []),
    {ok, TargetDbInfo, Res}.


create_docs(DbName) ->
    couch_replicator_test_helper:create_docs(DbName, [
        ?DDOC,
        #{
            <<"_id">> => <<"doc1">>,
            <<"class">> => <<"mammal">>,
            <<"value">> => 1
        },
        #{
            <<"_id">> => <<"doc2">>,
            <<"class">> => <<"amphibians">>,
            <<"value">> => 2
        },
        #{
            <<"_id">> => <<"doc3">>,
            <<"class">> => <<"reptiles">>,
            <<"value">> => 3
        },
        #{
            <<"_id">> => <<"doc4">>,
            <<"class">> => <<"arthropods">>,
            <<"value">> => 2
        }
    ]).
