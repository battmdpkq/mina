[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick
module T = Mina_numbers.Length

(*constants actually required for blockchain snark*)
(* k
   ,c
   ,slots_per_epoch
   ,slots_per_sub_window
   ,sub_windows_per_window
   ,checkpoint_window_size_in_slots
   ,block_window_duration_ms*)

module Poly = Genesis_constants.Protocol.Poly

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (T.Stable.V1.t, T.Stable.V1.t, Block_time.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving equal, ord, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind k = Int.gen_incl 1 5000 in
    let%bind delta = Int.gen_incl 0 5000 in
    let%bind slots_per_epoch = Int.gen_incl k (8 * k) >>| ( * ) 3
    and slots_per_sub_window = Int.gen_incl 1 ((k + 9) / 9) in
    let%bind grace_period_slots = Int.gen_incl 0 ((slots_per_epoch / 3) - 1) in
    (*TODO: Bug -> Block_time.(to_time x |> of_time) != x for certain values.
      Eg: 34702788243129 <--> 34702788243128, 8094 <--> 8093*)
    let%bind ms = Int64.(gen_log_uniform_incl 0L 9999999999999L) in
    let end_time = Block_time.of_int64 999999999999999L in
    let%map genesis_state_timestamp =
      Block_time.(gen_incl (of_int64 ms) end_time)
    in
    { Poly.k = T.of_int k
    ; delta = T.of_int delta
    ; slots_per_epoch = T.of_int slots_per_epoch
    ; slots_per_sub_window = T.of_int slots_per_sub_window
    ; grace_period_slots = T.of_int grace_period_slots
    ; genesis_state_timestamp
    }
end

type value = Value.t

let value_of_t
    ({ k
     ; delta
     ; slots_per_epoch
     ; slots_per_sub_window
     ; grace_period_slots
     ; genesis_state_timestamp
     } :
      Genesis_constants.Protocol.t ) : value =
  { k = T.of_int k
  ; delta = T.of_int delta
  ; slots_per_epoch = T.of_int slots_per_epoch
  ; slots_per_sub_window = T.of_int slots_per_sub_window
  ; grace_period_slots = T.of_int grace_period_slots
  ; genesis_state_timestamp = Block_time.of_int64 genesis_state_timestamp
  }

let t_of_value
    ({ k
     ; delta
     ; slots_per_epoch
     ; slots_per_sub_window
     ; grace_period_slots
     ; genesis_state_timestamp
     } :
      value ) : Genesis_constants.Protocol.t =
  { k = T.to_int k
  ; delta = T.to_int delta
  ; slots_per_epoch = T.to_int slots_per_epoch
  ; slots_per_sub_window = T.to_int slots_per_sub_window
  ; grace_period_slots = T.to_int grace_period_slots
  ; genesis_state_timestamp = Block_time.to_int64 genesis_state_timestamp
  }

let to_input
    ({ k
     ; delta
     ; slots_per_epoch
     ; slots_per_sub_window
     ; grace_period_slots
     ; genesis_state_timestamp
     } :
      value ) =
  Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
    [| T.to_input k
     ; T.to_input delta
     ; T.to_input slots_per_epoch
     ; T.to_input slots_per_sub_window
     ; T.to_input grace_period_slots
     ; Block_time.to_input genesis_state_timestamp
    |]

[%%if defined consensus_mechanism]

type var = (T.Checked.t, T.Checked.t, Block_time.Checked.t) Poly.t

let typ =
  Typ.of_hlistable
    [ T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; Block_time.Checked.typ
    ]
    ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let var_to_input
    ({ k
     ; delta
     ; slots_per_epoch
     ; slots_per_sub_window
     ; grace_period_slots
     ; genesis_state_timestamp
     } :
      var ) =
  let k = T.Checked.to_input k
  and delta = T.Checked.to_input delta
  and slots_per_epoch = T.Checked.to_input slots_per_epoch
  and slots_per_sub_window = T.Checked.to_input slots_per_sub_window
  and grace_period_slots = T.Checked.to_input grace_period_slots in
  let genesis_state_timestamp =
    Block_time.Checked.to_input genesis_state_timestamp
  in
  Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
    [| k
     ; delta
     ; slots_per_epoch
     ; slots_per_sub_window
     ; grace_period_slots
     ; genesis_state_timestamp
    |]

let%test_unit "value = var" =
  let compiled = Genesis_constants.for_unit_tests.protocol in
  let test protocol_constants =
    let open Snarky_backendless in
    let p_var =
      let%map p = exists typ ~compute:(As_prover0.return protocol_constants) in
      As_prover0.read typ p
    in
    let res = Or_error.ok_exn (run_and_check p_var) in
    [%test_eq: Value.t] res protocol_constants ;
    [%test_eq: Value.t] protocol_constants
      (t_of_value protocol_constants |> value_of_t)
  in
  Quickcheck.test ~trials:100 Value.gen
    ~examples:[ value_of_t compiled ]
    ~f:test

[%%endif]
