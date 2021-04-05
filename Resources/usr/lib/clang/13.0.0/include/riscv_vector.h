/*===---- riscv_vector.h - RISC-V V-extension RVVIntrinsics -------------------===
 *
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __RISCV_VECTOR_H
#define __RISCV_VECTOR_H

#include <stdint.h>
#include <stddef.h>

#ifndef __riscv_vector
#error "Vector intrinsics require the vector extension."
#endif

#ifdef __cplusplus
extern "C" {
#endif


#define vsetvl_e8mf8(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 5)
#define vsetvl_e8mf4(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 6)
#define vsetvl_e8mf2(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 7)
#define vsetvl_e8m1(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 0)
#define vsetvl_e8m2(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 1)
#define vsetvl_e8m4(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 2)
#define vsetvl_e8m8(avl) __builtin_rvv_vsetvli((size_t)(avl), 0, 3)

#define vsetvl_e16mf4(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 6)
#define vsetvl_e16mf2(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 7)
#define vsetvl_e16m1(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 0)
#define vsetvl_e16m2(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 1)
#define vsetvl_e16m4(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 2)
#define vsetvl_e16m8(avl) __builtin_rvv_vsetvli((size_t)(avl), 1, 3)

#define vsetvl_e32mf2(avl) __builtin_rvv_vsetvli((size_t)(avl), 2, 7)
#define vsetvl_e32m1(avl) __builtin_rvv_vsetvli((size_t)(avl), 2, 0)
#define vsetvl_e32m2(avl) __builtin_rvv_vsetvli((size_t)(avl), 2, 1)
#define vsetvl_e32m4(avl) __builtin_rvv_vsetvli((size_t)(avl), 2, 2)
#define vsetvl_e32m8(avl) __builtin_rvv_vsetvli((size_t)(avl), 2, 3)

#define vsetvl_e64m1(avl) __builtin_rvv_vsetvli((size_t)(avl), 3, 0)
#define vsetvl_e64m2(avl) __builtin_rvv_vsetvli((size_t)(avl), 3, 1)
#define vsetvl_e64m4(avl) __builtin_rvv_vsetvli((size_t)(avl), 3, 2)
#define vsetvl_e64m8(avl) __builtin_rvv_vsetvli((size_t)(avl), 3, 3)


#define vsetvlmax_e8mf8() __builtin_rvv_vsetvlimax(0, 5)
#define vsetvlmax_e8mf4() __builtin_rvv_vsetvlimax(0, 6)
#define vsetvlmax_e8mf2() __builtin_rvv_vsetvlimax(0, 7)
#define vsetvlmax_e8m1() __builtin_rvv_vsetvlimax(0, 0)
#define vsetvlmax_e8m2() __builtin_rvv_vsetvlimax(0, 1)
#define vsetvlmax_e8m4() __builtin_rvv_vsetvlimax(0, 2)
#define vsetvlmax_e8m8() __builtin_rvv_vsetvlimax(0, 3)

#define vsetvlmax_e16mf4() __builtin_rvv_vsetvlimax(1, 6)
#define vsetvlmax_e16mf2() __builtin_rvv_vsetvlimax(1, 7)
#define vsetvlmax_e16m1() __builtin_rvv_vsetvlimax(1, 0)
#define vsetvlmax_e16m2() __builtin_rvv_vsetvlimax(1, 1)
#define vsetvlmax_e16m4() __builtin_rvv_vsetvlimax(1, 2)
#define vsetvlmax_e16m8() __builtin_rvv_vsetvlimax(1, 3)

#define vsetvlmax_e32mf2() __builtin_rvv_vsetvlimax(2, 7)
#define vsetvlmax_e32m1() __builtin_rvv_vsetvlimax(2, 0)
#define vsetvlmax_e32m2() __builtin_rvv_vsetvlimax(2, 1)
#define vsetvlmax_e32m4() __builtin_rvv_vsetvlimax(2, 2)
#define vsetvlmax_e32m8() __builtin_rvv_vsetvlimax(2, 3)

#define vsetvlmax_e64m1() __builtin_rvv_vsetvlimax(3, 0)
#define vsetvlmax_e64m2() __builtin_rvv_vsetvlimax(3, 1)
#define vsetvlmax_e64m4() __builtin_rvv_vsetvlimax(3, 2)
#define vsetvlmax_e64m8() __builtin_rvv_vsetvlimax(3, 3)

typedef __rvv_bool64_t vbool64_t;
typedef __rvv_bool32_t vbool32_t;
typedef __rvv_bool16_t vbool16_t;
typedef __rvv_bool8_t vbool8_t;
typedef __rvv_bool4_t vbool4_t;
typedef __rvv_bool2_t vbool2_t;
typedef __rvv_bool1_t vbool1_t;
typedef __rvv_int8mf8_t vint8mf8_t;
typedef __rvv_uint8mf8_t vuint8mf8_t;
typedef __rvv_int8mf4_t vint8mf4_t;
typedef __rvv_uint8mf4_t vuint8mf4_t;
typedef __rvv_int8mf2_t vint8mf2_t;
typedef __rvv_uint8mf2_t vuint8mf2_t;
typedef __rvv_int8m1_t vint8m1_t;
typedef __rvv_uint8m1_t vuint8m1_t;
typedef __rvv_int8m2_t vint8m2_t;
typedef __rvv_uint8m2_t vuint8m2_t;
typedef __rvv_int8m4_t vint8m4_t;
typedef __rvv_uint8m4_t vuint8m4_t;
typedef __rvv_int8m8_t vint8m8_t;
typedef __rvv_uint8m8_t vuint8m8_t;
typedef __rvv_int16mf4_t vint16mf4_t;
typedef __rvv_uint16mf4_t vuint16mf4_t;
typedef __rvv_int16mf2_t vint16mf2_t;
typedef __rvv_uint16mf2_t vuint16mf2_t;
typedef __rvv_int16m1_t vint16m1_t;
typedef __rvv_uint16m1_t vuint16m1_t;
typedef __rvv_int16m2_t vint16m2_t;
typedef __rvv_uint16m2_t vuint16m2_t;
typedef __rvv_int16m4_t vint16m4_t;
typedef __rvv_uint16m4_t vuint16m4_t;
typedef __rvv_int16m8_t vint16m8_t;
typedef __rvv_uint16m8_t vuint16m8_t;
typedef __rvv_int32mf2_t vint32mf2_t;
typedef __rvv_uint32mf2_t vuint32mf2_t;
typedef __rvv_int32m1_t vint32m1_t;
typedef __rvv_uint32m1_t vuint32m1_t;
typedef __rvv_int32m2_t vint32m2_t;
typedef __rvv_uint32m2_t vuint32m2_t;
typedef __rvv_int32m4_t vint32m4_t;
typedef __rvv_uint32m4_t vuint32m4_t;
typedef __rvv_int32m8_t vint32m8_t;
typedef __rvv_uint32m8_t vuint32m8_t;
typedef __rvv_int64m1_t vint64m1_t;
typedef __rvv_uint64m1_t vuint64m1_t;
typedef __rvv_int64m2_t vint64m2_t;
typedef __rvv_uint64m2_t vuint64m2_t;
typedef __rvv_int64m4_t vint64m4_t;
typedef __rvv_uint64m4_t vuint64m4_t;
typedef __rvv_int64m8_t vint64m8_t;
typedef __rvv_uint64m8_t vuint64m8_t;
#if defined(__riscv_zfh)
typedef __rvv_float16mf4_t vfloat16mf4_t;
typedef __rvv_float16mf2_t vfloat16mf2_t;
typedef __rvv_float16m1_t vfloat16m1_t;
typedef __rvv_float16m2_t vfloat16m2_t;
typedef __rvv_float16m4_t vfloat16m4_t;
typedef __rvv_float16m8_t vfloat16m8_t;
#endif
#if defined(__riscv_f)
typedef __rvv_float32mf2_t vfloat32mf2_t;
typedef __rvv_float32m1_t vfloat32m1_t;
typedef __rvv_float32m2_t vfloat32m2_t;
typedef __rvv_float32m4_t vfloat32m4_t;
typedef __rvv_float32m8_t vfloat32m8_t;
#endif
#if defined(__riscv_d)
typedef __rvv_float64m1_t vfloat64m1_t;
typedef __rvv_float64m2_t vfloat64m2_t;
typedef __rvv_float64m4_t vfloat64m4_t;
typedef __rvv_float64m8_t vfloat64m8_t;
#endif

#define vadd_vv_i8m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8m1((vint8m1_t)(op0), (vint8m1_t)(op1), (size_t)(op2))
#define vadd_vv_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8m1_m((vint8m1_t)(op0), (vint8m1_t)(op1), (vint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_i8m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8m2((vint8m2_t)(op0), (vint8m2_t)(op1), (size_t)(op2))
#define vadd_vv_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8m2_m((vint8m2_t)(op0), (vint8m2_t)(op1), (vint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_i8m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8m4((vint8m4_t)(op0), (vint8m4_t)(op1), (size_t)(op2))
#define vadd_vv_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8m4_m((vint8m4_t)(op0), (vint8m4_t)(op1), (vint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vv_i8m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8m8((vint8m8_t)(op0), (vint8m8_t)(op1), (size_t)(op2))
#define vadd_vv_i8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8m8_m((vint8m8_t)(op0), (vint8m8_t)(op1), (vint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vadd_vv_i8mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8mf2((vint8mf2_t)(op0), (vint8mf2_t)(op1), (size_t)(op2))
#define vadd_vv_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8mf2_m((vint8mf2_t)(op0), (vint8mf2_t)(op1), (vint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_i8mf4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8mf4((vint8mf4_t)(op0), (vint8mf4_t)(op1), (size_t)(op2))
#define vadd_vv_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8mf4_m((vint8mf4_t)(op0), (vint8mf4_t)(op1), (vint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_i8mf8(op0, op1, op2) \
__builtin_rvv_vadd_vv_i8mf8((vint8mf8_t)(op0), (vint8mf8_t)(op1), (size_t)(op2))
#define vadd_vv_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i8mf8_m((vint8mf8_t)(op0), (vint8mf8_t)(op1), (vint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_i16m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16m1((vint16m1_t)(op0), (vint16m1_t)(op1), (size_t)(op2))
#define vadd_vv_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16m1_m((vint16m1_t)(op0), (vint16m1_t)(op1), (vint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_i16m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16m2((vint16m2_t)(op0), (vint16m2_t)(op1), (size_t)(op2))
#define vadd_vv_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16m2_m((vint16m2_t)(op0), (vint16m2_t)(op1), (vint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_i16m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16m4((vint16m4_t)(op0), (vint16m4_t)(op1), (size_t)(op2))
#define vadd_vv_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16m4_m((vint16m4_t)(op0), (vint16m4_t)(op1), (vint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_i16m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16m8((vint16m8_t)(op0), (vint16m8_t)(op1), (size_t)(op2))
#define vadd_vv_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16m8_m((vint16m8_t)(op0), (vint16m8_t)(op1), (vint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vv_i16mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16mf2((vint16mf2_t)(op0), (vint16mf2_t)(op1), (size_t)(op2))
#define vadd_vv_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16mf2_m((vint16mf2_t)(op0), (vint16mf2_t)(op1), (vint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_i16mf4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i16mf4((vint16mf4_t)(op0), (vint16mf4_t)(op1), (size_t)(op2))
#define vadd_vv_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i16mf4_m((vint16mf4_t)(op0), (vint16mf4_t)(op1), (vint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_i32m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_i32m1((vint32m1_t)(op0), (vint32m1_t)(op1), (size_t)(op2))
#define vadd_vv_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i32m1_m((vint32m1_t)(op0), (vint32m1_t)(op1), (vint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_i32m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i32m2((vint32m2_t)(op0), (vint32m2_t)(op1), (size_t)(op2))
#define vadd_vv_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i32m2_m((vint32m2_t)(op0), (vint32m2_t)(op1), (vint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_i32m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i32m4((vint32m4_t)(op0), (vint32m4_t)(op1), (size_t)(op2))
#define vadd_vv_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i32m4_m((vint32m4_t)(op0), (vint32m4_t)(op1), (vint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_i32m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_i32m8((vint32m8_t)(op0), (vint32m8_t)(op1), (size_t)(op2))
#define vadd_vv_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i32m8_m((vint32m8_t)(op0), (vint32m8_t)(op1), (vint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_i32mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i32mf2((vint32mf2_t)(op0), (vint32mf2_t)(op1), (size_t)(op2))
#define vadd_vv_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i32mf2_m((vint32mf2_t)(op0), (vint32mf2_t)(op1), (vint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_i64m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_i64m1((vint64m1_t)(op0), (vint64m1_t)(op1), (size_t)(op2))
#define vadd_vv_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i64m1_m((vint64m1_t)(op0), (vint64m1_t)(op1), (vint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_i64m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_i64m2((vint64m2_t)(op0), (vint64m2_t)(op1), (size_t)(op2))
#define vadd_vv_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i64m2_m((vint64m2_t)(op0), (vint64m2_t)(op1), (vint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_i64m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_i64m4((vint64m4_t)(op0), (vint64m4_t)(op1), (size_t)(op2))
#define vadd_vv_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i64m4_m((vint64m4_t)(op0), (vint64m4_t)(op1), (vint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_i64m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_i64m8((vint64m8_t)(op0), (vint64m8_t)(op1), (size_t)(op2))
#define vadd_vv_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_i64m8_m((vint64m8_t)(op0), (vint64m8_t)(op1), (vint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vle8_v_i8m1(op0, op1) \
__builtin_rvv_vle8_v_i8m1((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle8_v_i8m2(op0, op1) \
__builtin_rvv_vle8_v_i8m2((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle8_v_i8m4(op0, op1) \
__builtin_rvv_vle8_v_i8m4((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8m4_m((vint8m4_t)(op0), (const int8_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vle8_v_i8m8(op0, op1) \
__builtin_rvv_vle8_v_i8m8((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8m8_m((vint8m8_t)(op0), (const int8_t *)(op1), (vbool1_t)(op2), (size_t)(op3))
#define vle8_v_i8mf2(op0, op1) \
__builtin_rvv_vle8_v_i8mf2((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle8_v_i8mf4(op0, op1) \
__builtin_rvv_vle8_v_i8mf4((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8mf4_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle8_v_i8mf8(op0, op1) \
__builtin_rvv_vle8_v_i8mf8((const int8_t *)(op0), (size_t)(op1))
#define vle8_v_i8mf8_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vloxei64_v_u64m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u64m1((const uint64_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_u64m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u64m2((const uint64_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_u64m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u64m4((const uint64_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_u64m8(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u64m8((const uint64_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_i8m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8m1((vint8m1_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8m1_m((vint8m1_t)(op0), (vint8m1_t)(op1), (int8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_i8m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8m2((vint8m2_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8m2_m((vint8m2_t)(op0), (vint8m2_t)(op1), (int8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_i8m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8m4((vint8m4_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8m4_m((vint8m4_t)(op0), (vint8m4_t)(op1), (int8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vx_i8m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8m8((vint8m8_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8m8_m((vint8m8_t)(op0), (vint8m8_t)(op1), (int8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vadd_vx_i8mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8mf2((vint8mf2_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8mf2_m((vint8mf2_t)(op0), (vint8mf2_t)(op1), (int8_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_i8mf4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8mf4((vint8mf4_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8mf4_m((vint8mf4_t)(op0), (vint8mf4_t)(op1), (int8_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_i8mf8(op0, op1, op2) \
__builtin_rvv_vadd_vx_i8mf8((vint8mf8_t)(op0), (int8_t)(op1), (size_t)(op2))
#define vadd_vx_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i8mf8_m((vint8mf8_t)(op0), (vint8mf8_t)(op1), (int8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_i16m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16m1((vint16m1_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16m1_m((vint16m1_t)(op0), (vint16m1_t)(op1), (int16_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_i16m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16m2((vint16m2_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16m2_m((vint16m2_t)(op0), (vint16m2_t)(op1), (int16_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_i16m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16m4((vint16m4_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16m4_m((vint16m4_t)(op0), (vint16m4_t)(op1), (int16_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_i16m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16m8((vint16m8_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16m8_m((vint16m8_t)(op0), (vint16m8_t)(op1), (int16_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vx_i16mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16mf2((vint16mf2_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16mf2_m((vint16mf2_t)(op0), (vint16mf2_t)(op1), (int16_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_i16mf4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i16mf4((vint16mf4_t)(op0), (int16_t)(op1), (size_t)(op2))
#define vadd_vx_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i16mf4_m((vint16mf4_t)(op0), (vint16mf4_t)(op1), (int16_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_i32m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_i32m1((vint32m1_t)(op0), (int32_t)(op1), (size_t)(op2))
#define vadd_vx_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i32m1_m((vint32m1_t)(op0), (vint32m1_t)(op1), (int32_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_i32m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i32m2((vint32m2_t)(op0), (int32_t)(op1), (size_t)(op2))
#define vadd_vx_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i32m2_m((vint32m2_t)(op0), (vint32m2_t)(op1), (int32_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_i32m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i32m4((vint32m4_t)(op0), (int32_t)(op1), (size_t)(op2))
#define vadd_vx_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i32m4_m((vint32m4_t)(op0), (vint32m4_t)(op1), (int32_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_i32m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_i32m8((vint32m8_t)(op0), (int32_t)(op1), (size_t)(op2))
#define vadd_vx_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i32m8_m((vint32m8_t)(op0), (vint32m8_t)(op1), (int32_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_i32mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i32mf2((vint32mf2_t)(op0), (int32_t)(op1), (size_t)(op2))
#define vadd_vx_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i32mf2_m((vint32mf2_t)(op0), (vint32mf2_t)(op1), (int32_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_i64m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_i64m1((vint64m1_t)(op0), (int64_t)(op1), (size_t)(op2))
#define vadd_vx_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i64m1_m((vint64m1_t)(op0), (vint64m1_t)(op1), (int64_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_i64m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_i64m2((vint64m2_t)(op0), (int64_t)(op1), (size_t)(op2))
#define vadd_vx_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i64m2_m((vint64m2_t)(op0), (vint64m2_t)(op1), (int64_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_i64m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_i64m4((vint64m4_t)(op0), (int64_t)(op1), (size_t)(op2))
#define vadd_vx_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i64m4_m((vint64m4_t)(op0), (vint64m4_t)(op1), (int64_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_i64m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_i64m8((vint64m8_t)(op0), (int64_t)(op1), (size_t)(op2))
#define vadd_vx_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_i64m8_m((vint64m8_t)(op0), (vint64m8_t)(op1), (int64_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vse8_v_i8m1(op1, op0, op2) \
__builtin_rvv_vse8_v_i8m1((vint8m1_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8m1_m((vint8m1_t)(op0), (int8_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse8_v_i8m2(op1, op0, op2) \
__builtin_rvv_vse8_v_i8m2((vint8m2_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8m2_m((vint8m2_t)(op0), (int8_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse8_v_i8m4(op1, op0, op2) \
__builtin_rvv_vse8_v_i8m4((vint8m4_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8m4_m((vint8m4_t)(op0), (int8_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vse8_v_i8m8(op1, op0, op2) \
__builtin_rvv_vse8_v_i8m8((vint8m8_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8m8_m((vint8m8_t)(op0), (int8_t *)(op1), (vbool1_t)(op2), (size_t)(op3))
#define vse8_v_i8mf2(op1, op0, op2) \
__builtin_rvv_vse8_v_i8mf2((vint8mf2_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8mf2_m((vint8mf2_t)(op0), (int8_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse8_v_i8mf4(op1, op0, op2) \
__builtin_rvv_vse8_v_i8mf4((vint8mf4_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8mf4_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8mf4_m((vint8mf4_t)(op0), (int8_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse8_v_i8mf8(op1, op0, op2) \
__builtin_rvv_vse8_v_i8mf8((vint8mf8_t)(op0), (int8_t *)(op1), (size_t)(op2))
#define vse8_v_i8mf8_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_i8mf8_m((vint8mf8_t)(op0), (int8_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vadd_vv_u8m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8m1((vuint8m1_t)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vadd_vv_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8m1_m((vuint8m1_t)(op0), (vuint8m1_t)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_u8m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8m2((vuint8m2_t)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vadd_vv_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8m2_m((vuint8m2_t)(op0), (vuint8m2_t)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_u8m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8m4((vuint8m4_t)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vadd_vv_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8m4_m((vuint8m4_t)(op0), (vuint8m4_t)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vv_u8m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8m8((vuint8m8_t)(op0), (vuint8m8_t)(op1), (size_t)(op2))
#define vadd_vv_u8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8m8_m((vuint8m8_t)(op0), (vuint8m8_t)(op1), (vuint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vadd_vv_u8mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8mf2((vuint8mf2_t)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vadd_vv_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8mf2_m((vuint8mf2_t)(op0), (vuint8mf2_t)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_u8mf4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8mf4((vuint8mf4_t)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vadd_vv_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8mf4_m((vuint8mf4_t)(op0), (vuint8mf4_t)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_u8mf8(op0, op1, op2) \
__builtin_rvv_vadd_vv_u8mf8((vuint8mf8_t)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vadd_vv_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u8mf8_m((vuint8mf8_t)(op0), (vuint8mf8_t)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_u16m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16m1((vuint16m1_t)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vadd_vv_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16m1_m((vuint16m1_t)(op0), (vuint16m1_t)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_u16m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16m2((vuint16m2_t)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vadd_vv_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16m2_m((vuint16m2_t)(op0), (vuint16m2_t)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_u16m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16m4((vuint16m4_t)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vadd_vv_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16m4_m((vuint16m4_t)(op0), (vuint16m4_t)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_u16m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16m8((vuint16m8_t)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vadd_vv_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16m8_m((vuint16m8_t)(op0), (vuint16m8_t)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vv_u16mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16mf2((vuint16mf2_t)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vadd_vv_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16mf2_m((vuint16mf2_t)(op0), (vuint16mf2_t)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_u16mf4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u16mf4((vuint16mf4_t)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vadd_vv_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u16mf4_m((vuint16mf4_t)(op0), (vuint16mf4_t)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_u32m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_u32m1((vuint32m1_t)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vadd_vv_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u32m1_m((vuint32m1_t)(op0), (vuint32m1_t)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_u32m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u32m2((vuint32m2_t)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vadd_vv_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u32m2_m((vuint32m2_t)(op0), (vuint32m2_t)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_u32m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u32m4((vuint32m4_t)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vadd_vv_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u32m4_m((vuint32m4_t)(op0), (vuint32m4_t)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vv_u32m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_u32m8((vuint32m8_t)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vadd_vv_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u32m8_m((vuint32m8_t)(op0), (vuint32m8_t)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vv_u32mf2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u32mf2((vuint32mf2_t)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vadd_vv_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u32mf2_m((vuint32mf2_t)(op0), (vuint32mf2_t)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_u64m1(op0, op1, op2) \
__builtin_rvv_vadd_vv_u64m1((vuint64m1_t)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vadd_vv_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u64m1_m((vuint64m1_t)(op0), (vuint64m1_t)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vv_u64m2(op0, op1, op2) \
__builtin_rvv_vadd_vv_u64m2((vuint64m2_t)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vadd_vv_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u64m2_m((vuint64m2_t)(op0), (vuint64m2_t)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vv_u64m4(op0, op1, op2) \
__builtin_rvv_vadd_vv_u64m4((vuint64m4_t)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vadd_vv_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u64m4_m((vuint64m4_t)(op0), (vuint64m4_t)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vv_u64m8(op0, op1, op2) \
__builtin_rvv_vadd_vv_u64m8((vuint64m8_t)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vadd_vv_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vv_u64m8_m((vuint64m8_t)(op0), (vuint64m8_t)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_u8m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8m1((vuint8m1_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8m1_m((vuint8m1_t)(op0), (vuint8m1_t)(op1), (uint8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_u8m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8m2((vuint8m2_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8m2_m((vuint8m2_t)(op0), (vuint8m2_t)(op1), (uint8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_u8m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8m4((vuint8m4_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8m4_m((vuint8m4_t)(op0), (vuint8m4_t)(op1), (uint8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vx_u8m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8m8((vuint8m8_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8m8_m((vuint8m8_t)(op0), (vuint8m8_t)(op1), (uint8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vadd_vx_u8mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8mf2((vuint8mf2_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8mf2_m((vuint8mf2_t)(op0), (vuint8mf2_t)(op1), (uint8_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_u8mf4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8mf4((vuint8mf4_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8mf4_m((vuint8mf4_t)(op0), (vuint8mf4_t)(op1), (uint8_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_u8mf8(op0, op1, op2) \
__builtin_rvv_vadd_vx_u8mf8((vuint8mf8_t)(op0), (uint8_t)(op1), (size_t)(op2))
#define vadd_vx_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u8mf8_m((vuint8mf8_t)(op0), (vuint8mf8_t)(op1), (uint8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_u16m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16m1((vuint16m1_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16m1_m((vuint16m1_t)(op0), (vuint16m1_t)(op1), (uint16_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_u16m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16m2((vuint16m2_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16m2_m((vuint16m2_t)(op0), (vuint16m2_t)(op1), (uint16_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_u16m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16m4((vuint16m4_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16m4_m((vuint16m4_t)(op0), (vuint16m4_t)(op1), (uint16_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_u16m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16m8((vuint16m8_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16m8_m((vuint16m8_t)(op0), (vuint16m8_t)(op1), (uint16_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vadd_vx_u16mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16mf2((vuint16mf2_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16mf2_m((vuint16mf2_t)(op0), (vuint16mf2_t)(op1), (uint16_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_u16mf4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u16mf4((vuint16mf4_t)(op0), (uint16_t)(op1), (size_t)(op2))
#define vadd_vx_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u16mf4_m((vuint16mf4_t)(op0), (vuint16mf4_t)(op1), (uint16_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_u32m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_u32m1((vuint32m1_t)(op0), (uint32_t)(op1), (size_t)(op2))
#define vadd_vx_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u32m1_m((vuint32m1_t)(op0), (vuint32m1_t)(op1), (uint32_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_u32m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u32m2((vuint32m2_t)(op0), (uint32_t)(op1), (size_t)(op2))
#define vadd_vx_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u32m2_m((vuint32m2_t)(op0), (vuint32m2_t)(op1), (uint32_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_u32m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u32m4((vuint32m4_t)(op0), (uint32_t)(op1), (size_t)(op2))
#define vadd_vx_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u32m4_m((vuint32m4_t)(op0), (vuint32m4_t)(op1), (uint32_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vadd_vx_u32m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_u32m8((vuint32m8_t)(op0), (uint32_t)(op1), (size_t)(op2))
#define vadd_vx_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u32m8_m((vuint32m8_t)(op0), (vuint32m8_t)(op1), (uint32_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vadd_vx_u32mf2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u32mf2((vuint32mf2_t)(op0), (uint32_t)(op1), (size_t)(op2))
#define vadd_vx_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u32mf2_m((vuint32mf2_t)(op0), (vuint32mf2_t)(op1), (uint32_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_u64m1(op0, op1, op2) \
__builtin_rvv_vadd_vx_u64m1((vuint64m1_t)(op0), (uint64_t)(op1), (size_t)(op2))
#define vadd_vx_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u64m1_m((vuint64m1_t)(op0), (vuint64m1_t)(op1), (uint64_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vadd_vx_u64m2(op0, op1, op2) \
__builtin_rvv_vadd_vx_u64m2((vuint64m2_t)(op0), (uint64_t)(op1), (size_t)(op2))
#define vadd_vx_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u64m2_m((vuint64m2_t)(op0), (vuint64m2_t)(op1), (uint64_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vadd_vx_u64m4(op0, op1, op2) \
__builtin_rvv_vadd_vx_u64m4((vuint64m4_t)(op0), (uint64_t)(op1), (size_t)(op2))
#define vadd_vx_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u64m4_m((vuint64m4_t)(op0), (vuint64m4_t)(op1), (uint64_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vadd_vx_u64m8(op0, op1, op2) \
__builtin_rvv_vadd_vx_u64m8((vuint64m8_t)(op0), (uint64_t)(op1), (size_t)(op2))
#define vadd_vx_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vadd_vx_u64m8_m((vuint64m8_t)(op0), (vuint64m8_t)(op1), (uint64_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vse8_v_u8m1(op1, op0, op2) \
__builtin_rvv_vse8_v_u8m1((vuint8m1_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8m1_m((vuint8m1_t)(op0), (uint8_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse8_v_u8m2(op1, op0, op2) \
__builtin_rvv_vse8_v_u8m2((vuint8m2_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8m2_m((vuint8m2_t)(op0), (uint8_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse8_v_u8m4(op1, op0, op2) \
__builtin_rvv_vse8_v_u8m4((vuint8m4_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8m4_m((vuint8m4_t)(op0), (uint8_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vse8_v_u8m8(op1, op0, op2) \
__builtin_rvv_vse8_v_u8m8((vuint8m8_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8m8_m((vuint8m8_t)(op0), (uint8_t *)(op1), (vbool1_t)(op2), (size_t)(op3))
#define vse8_v_u8mf2(op1, op0, op2) \
__builtin_rvv_vse8_v_u8mf2((vuint8mf2_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8mf2_m((vuint8mf2_t)(op0), (uint8_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse8_v_u8mf4(op1, op0, op2) \
__builtin_rvv_vse8_v_u8mf4((vuint8mf4_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8mf4_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8mf4_m((vuint8mf4_t)(op0), (uint8_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse8_v_u8mf8(op1, op0, op2) \
__builtin_rvv_vse8_v_u8mf8((vuint8mf8_t)(op0), (uint8_t *)(op1), (size_t)(op2))
#define vse8_v_u8mf8_m(op2, op1, op0, op3) \
__builtin_rvv_vse8_v_u8mf8_m((vuint8mf8_t)(op0), (uint8_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle16_v_i16m1(op0, op1) \
__builtin_rvv_vle16_v_i16m1((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle16_v_i16m2(op0, op1) \
__builtin_rvv_vle16_v_i16m2((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle16_v_i16m4(op0, op1) \
__builtin_rvv_vle16_v_i16m4((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle16_v_i16m8(op0, op1) \
__builtin_rvv_vle16_v_i16m8((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16m8_m((vint16m8_t)(op0), (const int16_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vle16_v_i16mf2(op0, op1) \
__builtin_rvv_vle16_v_i16mf2((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle16_v_i16mf4(op0, op1) \
__builtin_rvv_vle16_v_i16mf4((const int16_t *)(op0), (size_t)(op1))
#define vle16_v_i16mf4_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle16_v_u16m1(op0, op1) \
__builtin_rvv_vle16_v_u16m1((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle16_v_u16m2(op0, op1) \
__builtin_rvv_vle16_v_u16m2((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle16_v_u16m4(op0, op1) \
__builtin_rvv_vle16_v_u16m4((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle16_v_u16m8(op0, op1) \
__builtin_rvv_vle16_v_u16m8((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16m8_m((vuint16m8_t)(op0), (const uint16_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vle16_v_u16mf2(op0, op1) \
__builtin_rvv_vle16_v_u16mf2((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle16_v_u16mf4(op0, op1) \
__builtin_rvv_vle16_v_u16mf4((const uint16_t *)(op0), (size_t)(op1))
#define vle16_v_u16mf4_m(op2, op0, op1, op3) \
__builtin_rvv_vle16_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle32_v_i32m1(op0, op1) \
__builtin_rvv_vle32_v_i32m1((const int32_t *)(op0), (size_t)(op1))
#define vle32_v_i32m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle32_v_i32m2(op0, op1) \
__builtin_rvv_vle32_v_i32m2((const int32_t *)(op0), (size_t)(op1))
#define vle32_v_i32m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle32_v_i32m4(op0, op1) \
__builtin_rvv_vle32_v_i32m4((const int32_t *)(op0), (size_t)(op1))
#define vle32_v_i32m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle32_v_i32m8(op0, op1) \
__builtin_rvv_vle32_v_i32m8((const int32_t *)(op0), (size_t)(op1))
#define vle32_v_i32m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle32_v_i32mf2(op0, op1) \
__builtin_rvv_vle32_v_i32mf2((const int32_t *)(op0), (size_t)(op1))
#define vle32_v_i32mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle32_v_u32m1(op0, op1) \
__builtin_rvv_vle32_v_u32m1((const uint32_t *)(op0), (size_t)(op1))
#define vle32_v_u32m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle32_v_u32m2(op0, op1) \
__builtin_rvv_vle32_v_u32m2((const uint32_t *)(op0), (size_t)(op1))
#define vle32_v_u32m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle32_v_u32m4(op0, op1) \
__builtin_rvv_vle32_v_u32m4((const uint32_t *)(op0), (size_t)(op1))
#define vle32_v_u32m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle32_v_u32m8(op0, op1) \
__builtin_rvv_vle32_v_u32m8((const uint32_t *)(op0), (size_t)(op1))
#define vle32_v_u32m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle32_v_u32mf2(op0, op1) \
__builtin_rvv_vle32_v_u32mf2((const uint32_t *)(op0), (size_t)(op1))
#define vle32_v_u32mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle64_v_i64m1(op0, op1) \
__builtin_rvv_vle64_v_i64m1((const int64_t *)(op0), (size_t)(op1))
#define vle64_v_i64m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle64_v_i64m2(op0, op1) \
__builtin_rvv_vle64_v_i64m2((const int64_t *)(op0), (size_t)(op1))
#define vle64_v_i64m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle64_v_i64m4(op0, op1) \
__builtin_rvv_vle64_v_i64m4((const int64_t *)(op0), (size_t)(op1))
#define vle64_v_i64m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle64_v_i64m8(op0, op1) \
__builtin_rvv_vle64_v_i64m8((const int64_t *)(op0), (size_t)(op1))
#define vle64_v_i64m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle64_v_u64m1(op0, op1) \
__builtin_rvv_vle64_v_u64m1((const uint64_t *)(op0), (size_t)(op1))
#define vle64_v_u64m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle64_v_u64m2(op0, op1) \
__builtin_rvv_vle64_v_u64m2((const uint64_t *)(op0), (size_t)(op1))
#define vle64_v_u64m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle64_v_u64m4(op0, op1) \
__builtin_rvv_vle64_v_u64m4((const uint64_t *)(op0), (size_t)(op1))
#define vle64_v_u64m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle64_v_u64m8(op0, op1) \
__builtin_rvv_vle64_v_u64m8((const uint64_t *)(op0), (size_t)(op1))
#define vle64_v_u64m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle8_v_u8m1(op0, op1) \
__builtin_rvv_vle8_v_u8m1((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle8_v_u8m2(op0, op1) \
__builtin_rvv_vle8_v_u8m2((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle8_v_u8m4(op0, op1) \
__builtin_rvv_vle8_v_u8m4((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8m4_m((vuint8m4_t)(op0), (const uint8_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vle8_v_u8m8(op0, op1) \
__builtin_rvv_vle8_v_u8m8((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8m8_m((vuint8m8_t)(op0), (const uint8_t *)(op1), (vbool1_t)(op2), (size_t)(op3))
#define vle8_v_u8mf2(op0, op1) \
__builtin_rvv_vle8_v_u8mf2((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle8_v_u8mf4(op0, op1) \
__builtin_rvv_vle8_v_u8mf4((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8mf4_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle8_v_u8mf8(op0, op1) \
__builtin_rvv_vle8_v_u8mf8((const uint8_t *)(op0), (size_t)(op1))
#define vle8_v_u8mf8_m(op2, op0, op1, op3) \
__builtin_rvv_vle8_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse16_v_i16m1(op1, op0, op2) \
__builtin_rvv_vse16_v_i16m1((vint16m1_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16m1_m((vint16m1_t)(op0), (int16_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse16_v_i16m2(op1, op0, op2) \
__builtin_rvv_vse16_v_i16m2((vint16m2_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16m2_m((vint16m2_t)(op0), (int16_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse16_v_i16m4(op1, op0, op2) \
__builtin_rvv_vse16_v_i16m4((vint16m4_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16m4_m((vint16m4_t)(op0), (int16_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse16_v_i16m8(op1, op0, op2) \
__builtin_rvv_vse16_v_i16m8((vint16m8_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16m8_m((vint16m8_t)(op0), (int16_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vse16_v_i16mf2(op1, op0, op2) \
__builtin_rvv_vse16_v_i16mf2((vint16mf2_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16mf2_m((vint16mf2_t)(op0), (int16_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse16_v_i16mf4(op1, op0, op2) \
__builtin_rvv_vse16_v_i16mf4((vint16mf4_t)(op0), (int16_t *)(op1), (size_t)(op2))
#define vse16_v_i16mf4_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_i16mf4_m((vint16mf4_t)(op0), (int16_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse16_v_u16m1(op1, op0, op2) \
__builtin_rvv_vse16_v_u16m1((vuint16m1_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16m1_m((vuint16m1_t)(op0), (uint16_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse16_v_u16m2(op1, op0, op2) \
__builtin_rvv_vse16_v_u16m2((vuint16m2_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16m2_m((vuint16m2_t)(op0), (uint16_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse16_v_u16m4(op1, op0, op2) \
__builtin_rvv_vse16_v_u16m4((vuint16m4_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16m4_m((vuint16m4_t)(op0), (uint16_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse16_v_u16m8(op1, op0, op2) \
__builtin_rvv_vse16_v_u16m8((vuint16m8_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16m8_m((vuint16m8_t)(op0), (uint16_t *)(op1), (vbool2_t)(op2), (size_t)(op3))
#define vse16_v_u16mf2(op1, op0, op2) \
__builtin_rvv_vse16_v_u16mf2((vuint16mf2_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16mf2_m((vuint16mf2_t)(op0), (uint16_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse16_v_u16mf4(op1, op0, op2) \
__builtin_rvv_vse16_v_u16mf4((vuint16mf4_t)(op0), (uint16_t *)(op1), (size_t)(op2))
#define vse16_v_u16mf4_m(op2, op1, op0, op3) \
__builtin_rvv_vse16_v_u16mf4_m((vuint16mf4_t)(op0), (uint16_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse32_v_i32m1(op1, op0, op2) \
__builtin_rvv_vse32_v_i32m1((vint32m1_t)(op0), (int32_t *)(op1), (size_t)(op2))
#define vse32_v_i32m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_i32m1_m((vint32m1_t)(op0), (int32_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse32_v_i32m2(op1, op0, op2) \
__builtin_rvv_vse32_v_i32m2((vint32m2_t)(op0), (int32_t *)(op1), (size_t)(op2))
#define vse32_v_i32m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_i32m2_m((vint32m2_t)(op0), (int32_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse32_v_i32m4(op1, op0, op2) \
__builtin_rvv_vse32_v_i32m4((vint32m4_t)(op0), (int32_t *)(op1), (size_t)(op2))
#define vse32_v_i32m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_i32m4_m((vint32m4_t)(op0), (int32_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse32_v_i32m8(op1, op0, op2) \
__builtin_rvv_vse32_v_i32m8((vint32m8_t)(op0), (int32_t *)(op1), (size_t)(op2))
#define vse32_v_i32m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_i32m8_m((vint32m8_t)(op0), (int32_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse32_v_i32mf2(op1, op0, op2) \
__builtin_rvv_vse32_v_i32mf2((vint32mf2_t)(op0), (int32_t *)(op1), (size_t)(op2))
#define vse32_v_i32mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_i32mf2_m((vint32mf2_t)(op0), (int32_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse32_v_u32m1(op1, op0, op2) \
__builtin_rvv_vse32_v_u32m1((vuint32m1_t)(op0), (uint32_t *)(op1), (size_t)(op2))
#define vse32_v_u32m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_u32m1_m((vuint32m1_t)(op0), (uint32_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse32_v_u32m2(op1, op0, op2) \
__builtin_rvv_vse32_v_u32m2((vuint32m2_t)(op0), (uint32_t *)(op1), (size_t)(op2))
#define vse32_v_u32m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_u32m2_m((vuint32m2_t)(op0), (uint32_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse32_v_u32m4(op1, op0, op2) \
__builtin_rvv_vse32_v_u32m4((vuint32m4_t)(op0), (uint32_t *)(op1), (size_t)(op2))
#define vse32_v_u32m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_u32m4_m((vuint32m4_t)(op0), (uint32_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse32_v_u32m8(op1, op0, op2) \
__builtin_rvv_vse32_v_u32m8((vuint32m8_t)(op0), (uint32_t *)(op1), (size_t)(op2))
#define vse32_v_u32m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_u32m8_m((vuint32m8_t)(op0), (uint32_t *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse32_v_u32mf2(op1, op0, op2) \
__builtin_rvv_vse32_v_u32mf2((vuint32mf2_t)(op0), (uint32_t *)(op1), (size_t)(op2))
#define vse32_v_u32mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_u32mf2_m((vuint32mf2_t)(op0), (uint32_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse64_v_i64m1(op1, op0, op2) \
__builtin_rvv_vse64_v_i64m1((vint64m1_t)(op0), (int64_t *)(op1), (size_t)(op2))
#define vse64_v_i64m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_i64m1_m((vint64m1_t)(op0), (int64_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse64_v_i64m2(op1, op0, op2) \
__builtin_rvv_vse64_v_i64m2((vint64m2_t)(op0), (int64_t *)(op1), (size_t)(op2))
#define vse64_v_i64m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_i64m2_m((vint64m2_t)(op0), (int64_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse64_v_i64m4(op1, op0, op2) \
__builtin_rvv_vse64_v_i64m4((vint64m4_t)(op0), (int64_t *)(op1), (size_t)(op2))
#define vse64_v_i64m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_i64m4_m((vint64m4_t)(op0), (int64_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse64_v_i64m8(op1, op0, op2) \
__builtin_rvv_vse64_v_i64m8((vint64m8_t)(op0), (int64_t *)(op1), (size_t)(op2))
#define vse64_v_i64m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_i64m8_m((vint64m8_t)(op0), (int64_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse64_v_u64m1(op1, op0, op2) \
__builtin_rvv_vse64_v_u64m1((vuint64m1_t)(op0), (uint64_t *)(op1), (size_t)(op2))
#define vse64_v_u64m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_u64m1_m((vuint64m1_t)(op0), (uint64_t *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse64_v_u64m2(op1, op0, op2) \
__builtin_rvv_vse64_v_u64m2((vuint64m2_t)(op0), (uint64_t *)(op1), (size_t)(op2))
#define vse64_v_u64m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_u64m2_m((vuint64m2_t)(op0), (uint64_t *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse64_v_u64m4(op1, op0, op2) \
__builtin_rvv_vse64_v_u64m4((vuint64m4_t)(op0), (uint64_t *)(op1), (size_t)(op2))
#define vse64_v_u64m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_u64m4_m((vuint64m4_t)(op0), (uint64_t *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse64_v_u64m8(op1, op0, op2) \
__builtin_rvv_vse64_v_u64m8((vuint64m8_t)(op0), (uint64_t *)(op1), (size_t)(op2))
#define vse64_v_u64m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_u64m8_m((vuint64m8_t)(op0), (uint64_t *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vluxei8_v_i8m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8m1((const int8_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_i8m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8m2((const int8_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_i8m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8m4((const int8_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vluxei8_v_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8m4_m((vint8m4_t)(op0), (const int8_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei8_v_i8m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8m8((const int8_t *)(op0), (vuint8m8_t)(op1), (size_t)(op2))
#define vluxei8_v_i8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8m8_m((vint8m8_t)(op0), (const int8_t *)(op1), (vuint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vluxei8_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8mf2((const int8_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8mf4((const int8_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i8mf8((const int8_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_i8m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8m1((const int8_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_i8m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8m2((const int8_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_i8m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8m4((const int8_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vluxei16_v_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8m4_m((vint8m4_t)(op0), (const int8_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei16_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8mf2((const int8_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8mf4((const int8_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i8mf8((const int8_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_u8m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8m1((const uint8_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_u8m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8m2((const uint8_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_u8m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8m4((const uint8_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vluxei16_v_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8m4_m((vuint8m4_t)(op0), (const uint8_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei16_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8mf2((const uint8_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8mf4((const uint8_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u8mf8((const uint8_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_i8m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i8m1((const int8_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_i8m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i8m2((const int8_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i8mf2((const int8_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i8mf4((const int8_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i8mf8((const int8_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_u8m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u8m1((const uint8_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_u8m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u8m2((const uint8_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u8mf2((const uint8_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u8mf4((const uint8_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u8mf8((const uint8_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_i8m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i8m1((const int8_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i8mf2((const int8_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i8mf4((const int8_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i8mf8((const int8_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_u8m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u8m1((const uint8_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u8mf2((const uint8_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u8mf4((const uint8_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u8mf8((const uint8_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_i16m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16m1((const int16_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_i16m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16m2((const int16_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_i16m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16m4((const int16_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_i16m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16m8((const int16_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vluxei8_v_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16m8_m((vint16m8_t)(op0), (const int16_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei8_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16mf2((const int16_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i16mf4((const int16_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_u16m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16m1((const uint16_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_u16m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16m2((const uint16_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_u16m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16m4((const uint16_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_u16m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16m8((const uint16_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vluxei8_v_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16m8_m((vuint16m8_t)(op0), (const uint16_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei8_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16mf2((const uint16_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u16mf4((const uint16_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_i16m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16m1((const int16_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_i16m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16m2((const int16_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_i16m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16m4((const int16_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_i16m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16m8((const int16_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vluxei16_v_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16m8_m((vint16m8_t)(op0), (const int16_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei16_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16mf2((const int16_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i16mf4((const int16_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_u16m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16m1((const uint16_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_u16m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16m2((const uint16_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_u16m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16m4((const uint16_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_u16m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16m8((const uint16_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vluxei16_v_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16m8_m((vuint16m8_t)(op0), (const uint16_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei16_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16mf2((const uint16_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u16mf4((const uint16_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_u8m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8m1((const uint8_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_u8m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8m2((const uint8_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_u8m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8m4((const uint8_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vluxei8_v_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8m4_m((vuint8m4_t)(op0), (const uint8_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vluxei8_v_u8m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8m8((const uint8_t *)(op0), (vuint8m8_t)(op1), (size_t)(op2))
#define vluxei8_v_u8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8m8_m((vuint8m8_t)(op0), (const uint8_t *)(op1), (vuint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vluxei8_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8mf2((const uint8_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8mf4((const uint8_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u8mf8((const uint8_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_i16m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i16m1((const int16_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_i16m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i16m2((const int16_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_i16m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i16m4((const int16_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i16mf2((const int16_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i16mf4((const int16_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_u16m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u16m1((const uint16_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_u16m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u16m2((const uint16_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_u16m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u16m4((const uint16_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u16mf2((const uint16_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u16mf4((const uint16_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_i16m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i16m1((const int16_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_i16m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i16m2((const int16_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i16mf2((const int16_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i16mf4((const int16_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_u16m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u16m1((const uint16_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_u16m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u16m2((const uint16_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u16mf2((const uint16_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u16mf4((const uint16_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_i32m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i32m1((const int32_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_i32m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i32m2((const int32_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_i32m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i32m4((const int32_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_i32m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i32m8((const int32_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i32mf2((const int32_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_u32m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u32m1((const uint32_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_u32m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u32m2((const uint32_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_u32m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u32m4((const uint32_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_u32m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u32m8((const uint32_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u32mf2((const uint32_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_i32m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i32m1((const int32_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_i32m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i32m2((const int32_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_i32m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i32m4((const int32_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_i32m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i32m8((const int32_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i32mf2((const int32_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_u32m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u32m1((const uint32_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_u32m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u32m2((const uint32_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_u32m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u32m4((const uint32_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_u32m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u32m8((const uint32_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u32mf2((const uint32_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_i32m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i32m1((const int32_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_i32m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i32m2((const int32_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_i32m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i32m4((const int32_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_i32m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i32m8((const int32_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i32mf2((const int32_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_u32m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u32m1((const uint32_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_u32m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u32m2((const uint32_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_u32m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u32m4((const uint32_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_u32m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u32m8((const uint32_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u32mf2((const uint32_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_i32m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i32m1((const int32_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_i32m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i32m2((const int32_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_i32m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i32m4((const int32_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i32mf2((const int32_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_u32m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u32m1((const uint32_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_u32m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u32m2((const uint32_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_u32m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u32m4((const uint32_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u32mf2((const uint32_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_i64m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i64m1((const int64_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_i64m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i64m2((const int64_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_i64m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i64m4((const int64_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_i64m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_i64m8((const int64_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_u64m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u64m1((const uint64_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_u64m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u64m2((const uint64_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_u64m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u64m4((const uint64_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_u64m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_u64m8((const uint64_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_i64m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i64m1((const int64_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_i64m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i64m2((const int64_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_i64m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i64m4((const int64_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_i64m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_i64m8((const int64_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_u64m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u64m1((const uint64_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_u64m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u64m2((const uint64_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_u64m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u64m4((const uint64_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_u64m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_u64m8((const uint64_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_i64m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i64m1((const int64_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_i64m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i64m2((const int64_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_i64m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i64m4((const int64_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_i64m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_i64m8((const int64_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_u64m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u64m1((const uint64_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_u64m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u64m2((const uint64_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_u64m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u64m4((const uint64_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_u64m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_u64m8((const uint64_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_i64m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i64m1((const int64_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_i64m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i64m2((const int64_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_i64m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i64m4((const int64_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_i64m8(op0, op1, op2) \
__builtin_rvv_vluxei64_v_i64m8((const int64_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_u64m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u64m1((const uint64_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_u64m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u64m2((const uint64_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_u64m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u64m4((const uint64_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_u64m8(op0, op1, op2) \
__builtin_rvv_vluxei64_v_u64m8((const uint64_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_i8m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8m1((const int8_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_i8m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8m2((const int8_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_i8m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8m4((const int8_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vloxei8_v_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8m4_m((vint8m4_t)(op0), (const int8_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei8_v_i8m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8m8((const int8_t *)(op0), (vuint8m8_t)(op1), (size_t)(op2))
#define vloxei8_v_i8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8m8_m((vint8m8_t)(op0), (const int8_t *)(op1), (vuint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vloxei8_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8mf2((const int8_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8mf4((const int8_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i8mf8((const int8_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_u8m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8m1((const uint8_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_u8m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8m2((const uint8_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_u8m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8m4((const uint8_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vloxei8_v_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8m4_m((vuint8m4_t)(op0), (const uint8_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei8_v_u8m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8m8((const uint8_t *)(op0), (vuint8m8_t)(op1), (size_t)(op2))
#define vloxei8_v_u8m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8m8_m((vuint8m8_t)(op0), (const uint8_t *)(op1), (vuint8m8_t)(op2), (vbool1_t)(op3), (size_t)(op4))
#define vloxei8_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8mf2((const uint8_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8mf4((const uint8_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u8mf8((const uint8_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_i8m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8m1((const int8_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_i8m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8m2((const int8_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_i8m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8m4((const int8_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vloxei16_v_i8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8m4_m((vint8m4_t)(op0), (const int8_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei16_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8mf2((const int8_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8mf4((const int8_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i8mf8((const int8_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_u8m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8m1((const uint8_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_u8m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8m2((const uint8_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_u8m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8m4((const uint8_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vloxei16_v_u8m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8m4_m((vuint8m4_t)(op0), (const uint8_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei16_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8mf2((const uint8_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8mf4((const uint8_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u8mf8((const uint8_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_i8m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i8m1((const int8_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_i8m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i8m2((const int8_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_i8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i8m2_m((vint8m2_t)(op0), (const int8_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i8mf2((const int8_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i8mf4((const int8_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i8mf8((const int8_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_u8m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u8m1((const uint8_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_u8m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u8m2((const uint8_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_u8m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u8m2_m((vuint8m2_t)(op0), (const uint8_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u8mf2((const uint8_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u8mf4((const uint8_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u8mf8((const uint8_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_i8m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i8m1((const int8_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_i8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i8m1_m((vint8m1_t)(op0), (const int8_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_i8mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i8mf2((const int8_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_i8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i8mf2_m((vint8mf2_t)(op0), (const int8_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_i8mf4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i8mf4((const int8_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_i8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i8mf4_m((vint8mf4_t)(op0), (const int8_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_i8mf8(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i8mf8((const int8_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_i8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i8mf8_m((vint8mf8_t)(op0), (const int8_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_u8m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u8m1((const uint8_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_u8m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u8m1_m((vuint8m1_t)(op0), (const uint8_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_u8mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u8mf2((const uint8_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_u8mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u8mf2_m((vuint8mf2_t)(op0), (const uint8_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_u8mf4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u8mf4((const uint8_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_u8mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u8mf4_m((vuint8mf4_t)(op0), (const uint8_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_u8mf8(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u8mf8((const uint8_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_u8mf8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u8mf8_m((vuint8mf8_t)(op0), (const uint8_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_i16m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16m1((const int16_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_i16m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16m2((const int16_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_i16m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16m4((const int16_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_i16m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16m8((const int16_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vloxei8_v_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16m8_m((vint16m8_t)(op0), (const int16_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei8_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16mf2((const int16_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i16mf4((const int16_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_u16m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16m1((const uint16_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_u16m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16m2((const uint16_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_u16m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16m4((const uint16_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_u16m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16m8((const uint16_t *)(op0), (vuint8m4_t)(op1), (size_t)(op2))
#define vloxei8_v_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16m8_m((vuint16m8_t)(op0), (const uint16_t *)(op1), (vuint8m4_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei8_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16mf2((const uint16_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u16mf4((const uint16_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_i16m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16m1((const int16_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_i16m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16m2((const int16_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_i16m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16m4((const int16_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_i16m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16m8((const int16_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vloxei16_v_i16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16m8_m((vint16m8_t)(op0), (const int16_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei16_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16mf2((const int16_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i16mf4((const int16_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_u16m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16m1((const uint16_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_u16m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16m2((const uint16_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_u16m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16m4((const uint16_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_u16m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16m8((const uint16_t *)(op0), (vuint16m8_t)(op1), (size_t)(op2))
#define vloxei16_v_u16m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16m8_m((vuint16m8_t)(op0), (const uint16_t *)(op1), (vuint16m8_t)(op2), (vbool2_t)(op3), (size_t)(op4))
#define vloxei16_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16mf2((const uint16_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u16mf4((const uint16_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_i16m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i16m1((const int16_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_i16m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i16m2((const int16_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_i16m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i16m4((const int16_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_i16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i16m4_m((vint16m4_t)(op0), (const int16_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i16mf2((const int16_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i16mf4((const int16_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_u16m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u16m1((const uint16_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_u16m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u16m2((const uint16_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_u16m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u16m4((const uint16_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_u16m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u16m4_m((vuint16m4_t)(op0), (const uint16_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u16mf2((const uint16_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u16mf4((const uint16_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_i16m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i16m1((const int16_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_i16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i16m1_m((vint16m1_t)(op0), (const int16_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_i16m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i16m2((const int16_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_i16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i16m2_m((vint16m2_t)(op0), (const int16_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_i16mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i16mf2((const int16_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_i16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i16mf2_m((vint16mf2_t)(op0), (const int16_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_i16mf4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i16mf4((const int16_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_i16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i16mf4_m((vint16mf4_t)(op0), (const int16_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_u16m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u16m1((const uint16_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_u16m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u16m1_m((vuint16m1_t)(op0), (const uint16_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_u16m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u16m2((const uint16_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_u16m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u16m2_m((vuint16m2_t)(op0), (const uint16_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_u16mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u16mf2((const uint16_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_u16mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u16mf2_m((vuint16mf2_t)(op0), (const uint16_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_u16mf4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u16mf4((const uint16_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_u16mf4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u16mf4_m((vuint16mf4_t)(op0), (const uint16_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_i32m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i32m1((const int32_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_i32m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i32m2((const int32_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_i32m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i32m4((const int32_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_i32m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i32m8((const int32_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i32mf2((const int32_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_u32m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u32m1((const uint32_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_u32m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u32m2((const uint32_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_u32m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u32m4((const uint32_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_u32m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u32m8((const uint32_t *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u32mf2((const uint32_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_i32m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i32m1((const int32_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_i32m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i32m2((const int32_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_i32m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i32m4((const int32_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_i32m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i32m8((const int32_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i32mf2((const int32_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_u32m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u32m1((const uint32_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_u32m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u32m2((const uint32_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_u32m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u32m4((const uint32_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_u32m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u32m8((const uint32_t *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u32mf2((const uint32_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_i32m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i32m1((const int32_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_i32m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i32m2((const int32_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_i32m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i32m4((const int32_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_i32m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i32m8((const int32_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_i32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i32m8_m((vint32m8_t)(op0), (const int32_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i32mf2((const int32_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_u32m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u32m1((const uint32_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_u32m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u32m2((const uint32_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_u32m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u32m4((const uint32_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_u32m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u32m8((const uint32_t *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_u32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u32m8_m((vuint32m8_t)(op0), (const uint32_t *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u32mf2((const uint32_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_i32m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i32m1((const int32_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_i32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i32m1_m((vint32m1_t)(op0), (const int32_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_i32m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i32m2((const int32_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_i32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i32m2_m((vint32m2_t)(op0), (const int32_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_i32m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i32m4((const int32_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_i32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i32m4_m((vint32m4_t)(op0), (const int32_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_i32mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i32mf2((const int32_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_i32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i32mf2_m((vint32mf2_t)(op0), (const int32_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_u32m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u32m1((const uint32_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_u32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u32m1_m((vuint32m1_t)(op0), (const uint32_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_u32m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u32m2((const uint32_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_u32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u32m2_m((vuint32m2_t)(op0), (const uint32_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_u32m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u32m4((const uint32_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_u32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u32m4_m((vuint32m4_t)(op0), (const uint32_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_u32mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_u32mf2((const uint32_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_u32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_u32mf2_m((vuint32mf2_t)(op0), (const uint32_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_i64m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i64m1((const int64_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_i64m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i64m2((const int64_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_i64m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i64m4((const int64_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_i64m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_i64m8((const int64_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_u64m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u64m1((const uint64_t *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_u64m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u64m2((const uint64_t *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_u64m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u64m4((const uint64_t *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_u64m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_u64m8((const uint64_t *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_i64m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i64m1((const int64_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_i64m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i64m2((const int64_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_i64m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i64m4((const int64_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_i64m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_i64m8((const int64_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_u64m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u64m1((const uint64_t *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_u64m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u64m2((const uint64_t *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_u64m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u64m4((const uint64_t *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_u64m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_u64m8((const uint64_t *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_i64m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i64m1((const int64_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_i64m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i64m2((const int64_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_i64m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i64m4((const int64_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_i64m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_i64m8((const int64_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_u64m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u64m1((const uint64_t *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_u64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u64m1_m((vuint64m1_t)(op0), (const uint64_t *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_u64m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u64m2((const uint64_t *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_u64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u64m2_m((vuint64m2_t)(op0), (const uint64_t *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_u64m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u64m4((const uint64_t *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_u64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u64m4_m((vuint64m4_t)(op0), (const uint64_t *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_u64m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_u64m8((const uint64_t *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_u64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_u64m8_m((vuint64m8_t)(op0), (const uint64_t *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_i64m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i64m1((const int64_t *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_i64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i64m1_m((vint64m1_t)(op0), (const int64_t *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_i64m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i64m2((const int64_t *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_i64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i64m2_m((vint64m2_t)(op0), (const int64_t *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_i64m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i64m4((const int64_t *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_i64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i64m4_m((vint64m4_t)(op0), (const int64_t *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_i64m8(op0, op1, op2) \
__builtin_rvv_vloxei64_v_i64m8((const int64_t *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_i64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_i64m8_m((vint64m8_t)(op0), (const int64_t *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#if defined(__riscv_f)
#define vloxei8_v_f32m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f32m1((const float *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_f32m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f32m2((const float *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_f32m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f32m4((const float *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei8_v_f32m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f32m8((const float *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vloxei8_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei8_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f32mf2((const float *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_f32m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f32m1((const float *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_f32m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f32m2((const float *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_f32m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f32m4((const float *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_f32m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f32m8((const float *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vloxei16_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei16_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f32mf2((const float *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_f32m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f32m1((const float *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_f32m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f32m2((const float *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_f32m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f32m4((const float *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_f32m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f32m8((const float *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vloxei32_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vloxei32_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f32mf2((const float *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_f32m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f32m1((const float *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_f32m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f32m2((const float *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_f32m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f32m4((const float *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f32mf2((const float *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vfadd_vv_f32m1(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f32m1((vfloat32m1_t)(op0), (vfloat32m1_t)(op1), (size_t)(op2))
#define vfadd_vv_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f32m1_m((vfloat32m1_t)(op0), (vfloat32m1_t)(op1), (vfloat32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vfadd_vv_f32m2(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f32m2((vfloat32m2_t)(op0), (vfloat32m2_t)(op1), (size_t)(op2))
#define vfadd_vv_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f32m2_m((vfloat32m2_t)(op0), (vfloat32m2_t)(op1), (vfloat32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vfadd_vv_f32m4(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f32m4((vfloat32m4_t)(op0), (vfloat32m4_t)(op1), (size_t)(op2))
#define vfadd_vv_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f32m4_m((vfloat32m4_t)(op0), (vfloat32m4_t)(op1), (vfloat32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vfadd_vv_f32m8(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f32m8((vfloat32m8_t)(op0), (vfloat32m8_t)(op1), (size_t)(op2))
#define vfadd_vv_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f32m8_m((vfloat32m8_t)(op0), (vfloat32m8_t)(op1), (vfloat32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vfadd_vv_f32mf2(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f32mf2((vfloat32mf2_t)(op0), (vfloat32mf2_t)(op1), (size_t)(op2))
#define vfadd_vv_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f32mf2_m((vfloat32mf2_t)(op0), (vfloat32mf2_t)(op1), (vfloat32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vfadd_vf_f32m1(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f32m1((vfloat32m1_t)(op0), (float)(op1), (size_t)(op2))
#define vfadd_vf_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f32m1_m((vfloat32m1_t)(op0), (vfloat32m1_t)(op1), (float)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vfadd_vf_f32m2(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f32m2((vfloat32m2_t)(op0), (float)(op1), (size_t)(op2))
#define vfadd_vf_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f32m2_m((vfloat32m2_t)(op0), (vfloat32m2_t)(op1), (float)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vfadd_vf_f32m4(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f32m4((vfloat32m4_t)(op0), (float)(op1), (size_t)(op2))
#define vfadd_vf_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f32m4_m((vfloat32m4_t)(op0), (vfloat32m4_t)(op1), (float)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vfadd_vf_f32m8(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f32m8((vfloat32m8_t)(op0), (float)(op1), (size_t)(op2))
#define vfadd_vf_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f32m8_m((vfloat32m8_t)(op0), (vfloat32m8_t)(op1), (float)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vfadd_vf_f32mf2(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f32mf2((vfloat32mf2_t)(op0), (float)(op1), (size_t)(op2))
#define vfadd_vf_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f32mf2_m((vfloat32mf2_t)(op0), (vfloat32mf2_t)(op1), (float)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vle32_v_f32m1(op0, op1) \
__builtin_rvv_vle32_v_f32m1((const float *)(op0), (size_t)(op1))
#define vle32_v_f32m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle32_v_f32m2(op0, op1) \
__builtin_rvv_vle32_v_f32m2((const float *)(op0), (size_t)(op1))
#define vle32_v_f32m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle32_v_f32m4(op0, op1) \
__builtin_rvv_vle32_v_f32m4((const float *)(op0), (size_t)(op1))
#define vle32_v_f32m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vle32_v_f32m8(op0, op1) \
__builtin_rvv_vle32_v_f32m8((const float *)(op0), (size_t)(op1))
#define vle32_v_f32m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vle32_v_f32mf2(op0, op1) \
__builtin_rvv_vle32_v_f32mf2((const float *)(op0), (size_t)(op1))
#define vle32_v_f32mf2_m(op2, op0, op1, op3) \
__builtin_rvv_vle32_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse32_v_f32m1(op1, op0, op2) \
__builtin_rvv_vse32_v_f32m1((vfloat32m1_t)(op0), (float *)(op1), (size_t)(op2))
#define vse32_v_f32m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_f32m1_m((vfloat32m1_t)(op0), (float *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse32_v_f32m2(op1, op0, op2) \
__builtin_rvv_vse32_v_f32m2((vfloat32m2_t)(op0), (float *)(op1), (size_t)(op2))
#define vse32_v_f32m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_f32m2_m((vfloat32m2_t)(op0), (float *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse32_v_f32m4(op1, op0, op2) \
__builtin_rvv_vse32_v_f32m4((vfloat32m4_t)(op0), (float *)(op1), (size_t)(op2))
#define vse32_v_f32m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_f32m4_m((vfloat32m4_t)(op0), (float *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse32_v_f32m8(op1, op0, op2) \
__builtin_rvv_vse32_v_f32m8((vfloat32m8_t)(op0), (float *)(op1), (size_t)(op2))
#define vse32_v_f32m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_f32m8_m((vfloat32m8_t)(op0), (float *)(op1), (vbool4_t)(op2), (size_t)(op3))
#define vse32_v_f32mf2(op1, op0, op2) \
__builtin_rvv_vse32_v_f32mf2((vfloat32mf2_t)(op0), (float *)(op1), (size_t)(op2))
#define vse32_v_f32mf2_m(op2, op1, op0, op3) \
__builtin_rvv_vse32_v_f32mf2_m((vfloat32mf2_t)(op0), (float *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vluxei8_v_f32m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f32m1((const float *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_f32m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f32m2((const float *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_f32m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f32m4((const float *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei8_v_f32m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f32m8((const float *)(op0), (vuint8m2_t)(op1), (size_t)(op2))
#define vluxei8_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint8m2_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei8_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f32mf2((const float *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_f32m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f32m1((const float *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_f32m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f32m2((const float *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_f32m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f32m4((const float *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_f32m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f32m8((const float *)(op0), (vuint16m4_t)(op1), (size_t)(op2))
#define vluxei16_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint16m4_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei16_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f32mf2((const float *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_f32m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f32m1((const float *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_f32m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f32m2((const float *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_f32m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f32m4((const float *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_f32m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f32m8((const float *)(op0), (vuint32m8_t)(op1), (size_t)(op2))
#define vluxei32_v_f32m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f32m8_m((vfloat32m8_t)(op0), (const float *)(op1), (vuint32m8_t)(op2), (vbool4_t)(op3), (size_t)(op4))
#define vluxei32_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f32mf2((const float *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_f32m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f32m1((const float *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_f32m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f32m1_m((vfloat32m1_t)(op0), (const float *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_f32m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f32m2((const float *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_f32m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f32m2_m((vfloat32m2_t)(op0), (const float *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_f32m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f32m4((const float *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_f32m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f32m4_m((vfloat32m4_t)(op0), (const float *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_f32mf2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f32mf2((const float *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_f32mf2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f32mf2_m((vfloat32mf2_t)(op0), (const float *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#endif

#if defined(__riscv_d)
#define vloxei8_v_f64m1(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f64m1((const double *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vloxei8_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei8_v_f64m2(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f64m2((const double *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vloxei8_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei8_v_f64m4(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f64m4((const double *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vloxei8_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei8_v_f64m8(op0, op1, op2) \
__builtin_rvv_vloxei8_v_f64m8((const double *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vloxei8_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei8_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei16_v_f64m1(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f64m1((const double *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vloxei16_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei16_v_f64m2(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f64m2((const double *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vloxei16_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei16_v_f64m4(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f64m4((const double *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vloxei16_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei16_v_f64m8(op0, op1, op2) \
__builtin_rvv_vloxei16_v_f64m8((const double *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vloxei16_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei16_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei32_v_f64m1(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f64m1((const double *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vloxei32_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei32_v_f64m2(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f64m2((const double *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vloxei32_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei32_v_f64m4(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f64m4((const double *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vloxei32_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei32_v_f64m8(op0, op1, op2) \
__builtin_rvv_vloxei32_v_f64m8((const double *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vloxei32_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei32_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vloxei64_v_f64m1(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f64m1((const double *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vloxei64_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vloxei64_v_f64m2(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f64m2((const double *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vloxei64_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vloxei64_v_f64m4(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f64m4((const double *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vloxei64_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vloxei64_v_f64m8(op0, op1, op2) \
__builtin_rvv_vloxei64_v_f64m8((const double *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vloxei64_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vloxei64_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vfadd_vv_f64m1(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f64m1((vfloat64m1_t)(op0), (vfloat64m1_t)(op1), (size_t)(op2))
#define vfadd_vv_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f64m1_m((vfloat64m1_t)(op0), (vfloat64m1_t)(op1), (vfloat64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vfadd_vv_f64m2(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f64m2((vfloat64m2_t)(op0), (vfloat64m2_t)(op1), (size_t)(op2))
#define vfadd_vv_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f64m2_m((vfloat64m2_t)(op0), (vfloat64m2_t)(op1), (vfloat64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vfadd_vv_f64m4(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f64m4((vfloat64m4_t)(op0), (vfloat64m4_t)(op1), (size_t)(op2))
#define vfadd_vv_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f64m4_m((vfloat64m4_t)(op0), (vfloat64m4_t)(op1), (vfloat64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vfadd_vv_f64m8(op0, op1, op2) \
__builtin_rvv_vfadd_vv_f64m8((vfloat64m8_t)(op0), (vfloat64m8_t)(op1), (size_t)(op2))
#define vfadd_vv_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vv_f64m8_m((vfloat64m8_t)(op0), (vfloat64m8_t)(op1), (vfloat64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vfadd_vf_f64m1(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f64m1((vfloat64m1_t)(op0), (double)(op1), (size_t)(op2))
#define vfadd_vf_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f64m1_m((vfloat64m1_t)(op0), (vfloat64m1_t)(op1), (double)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vfadd_vf_f64m2(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f64m2((vfloat64m2_t)(op0), (double)(op1), (size_t)(op2))
#define vfadd_vf_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f64m2_m((vfloat64m2_t)(op0), (vfloat64m2_t)(op1), (double)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vfadd_vf_f64m4(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f64m4((vfloat64m4_t)(op0), (double)(op1), (size_t)(op2))
#define vfadd_vf_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f64m4_m((vfloat64m4_t)(op0), (vfloat64m4_t)(op1), (double)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vfadd_vf_f64m8(op0, op1, op2) \
__builtin_rvv_vfadd_vf_f64m8((vfloat64m8_t)(op0), (double)(op1), (size_t)(op2))
#define vfadd_vf_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vfadd_vf_f64m8_m((vfloat64m8_t)(op0), (vfloat64m8_t)(op1), (double)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vle64_v_f64m1(op0, op1) \
__builtin_rvv_vle64_v_f64m1((const double *)(op0), (size_t)(op1))
#define vle64_v_f64m1_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vle64_v_f64m2(op0, op1) \
__builtin_rvv_vle64_v_f64m2((const double *)(op0), (size_t)(op1))
#define vle64_v_f64m2_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vle64_v_f64m4(op0, op1) \
__builtin_rvv_vle64_v_f64m4((const double *)(op0), (size_t)(op1))
#define vle64_v_f64m4_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vle64_v_f64m8(op0, op1) \
__builtin_rvv_vle64_v_f64m8((const double *)(op0), (size_t)(op1))
#define vle64_v_f64m8_m(op2, op0, op1, op3) \
__builtin_rvv_vle64_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vse64_v_f64m1(op1, op0, op2) \
__builtin_rvv_vse64_v_f64m1((vfloat64m1_t)(op0), (double *)(op1), (size_t)(op2))
#define vse64_v_f64m1_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_f64m1_m((vfloat64m1_t)(op0), (double *)(op1), (vbool64_t)(op2), (size_t)(op3))
#define vse64_v_f64m2(op1, op0, op2) \
__builtin_rvv_vse64_v_f64m2((vfloat64m2_t)(op0), (double *)(op1), (size_t)(op2))
#define vse64_v_f64m2_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_f64m2_m((vfloat64m2_t)(op0), (double *)(op1), (vbool32_t)(op2), (size_t)(op3))
#define vse64_v_f64m4(op1, op0, op2) \
__builtin_rvv_vse64_v_f64m4((vfloat64m4_t)(op0), (double *)(op1), (size_t)(op2))
#define vse64_v_f64m4_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_f64m4_m((vfloat64m4_t)(op0), (double *)(op1), (vbool16_t)(op2), (size_t)(op3))
#define vse64_v_f64m8(op1, op0, op2) \
__builtin_rvv_vse64_v_f64m8((vfloat64m8_t)(op0), (double *)(op1), (size_t)(op2))
#define vse64_v_f64m8_m(op2, op1, op0, op3) \
__builtin_rvv_vse64_v_f64m8_m((vfloat64m8_t)(op0), (double *)(op1), (vbool8_t)(op2), (size_t)(op3))
#define vluxei8_v_f64m1(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f64m1((const double *)(op0), (vuint8mf8_t)(op1), (size_t)(op2))
#define vluxei8_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint8mf8_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei8_v_f64m2(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f64m2((const double *)(op0), (vuint8mf4_t)(op1), (size_t)(op2))
#define vluxei8_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint8mf4_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei8_v_f64m4(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f64m4((const double *)(op0), (vuint8mf2_t)(op1), (size_t)(op2))
#define vluxei8_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint8mf2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei8_v_f64m8(op0, op1, op2) \
__builtin_rvv_vluxei8_v_f64m8((const double *)(op0), (vuint8m1_t)(op1), (size_t)(op2))
#define vluxei8_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei8_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint8m1_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei16_v_f64m1(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f64m1((const double *)(op0), (vuint16mf4_t)(op1), (size_t)(op2))
#define vluxei16_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint16mf4_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei16_v_f64m2(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f64m2((const double *)(op0), (vuint16mf2_t)(op1), (size_t)(op2))
#define vluxei16_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint16mf2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei16_v_f64m4(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f64m4((const double *)(op0), (vuint16m1_t)(op1), (size_t)(op2))
#define vluxei16_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint16m1_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei16_v_f64m8(op0, op1, op2) \
__builtin_rvv_vluxei16_v_f64m8((const double *)(op0), (vuint16m2_t)(op1), (size_t)(op2))
#define vluxei16_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei16_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint16m2_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei32_v_f64m1(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f64m1((const double *)(op0), (vuint32mf2_t)(op1), (size_t)(op2))
#define vluxei32_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint32mf2_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei32_v_f64m2(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f64m2((const double *)(op0), (vuint32m1_t)(op1), (size_t)(op2))
#define vluxei32_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint32m1_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei32_v_f64m4(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f64m4((const double *)(op0), (vuint32m2_t)(op1), (size_t)(op2))
#define vluxei32_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint32m2_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei32_v_f64m8(op0, op1, op2) \
__builtin_rvv_vluxei32_v_f64m8((const double *)(op0), (vuint32m4_t)(op1), (size_t)(op2))
#define vluxei32_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei32_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint32m4_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#define vluxei64_v_f64m1(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f64m1((const double *)(op0), (vuint64m1_t)(op1), (size_t)(op2))
#define vluxei64_v_f64m1_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f64m1_m((vfloat64m1_t)(op0), (const double *)(op1), (vuint64m1_t)(op2), (vbool64_t)(op3), (size_t)(op4))
#define vluxei64_v_f64m2(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f64m2((const double *)(op0), (vuint64m2_t)(op1), (size_t)(op2))
#define vluxei64_v_f64m2_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f64m2_m((vfloat64m2_t)(op0), (const double *)(op1), (vuint64m2_t)(op2), (vbool32_t)(op3), (size_t)(op4))
#define vluxei64_v_f64m4(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f64m4((const double *)(op0), (vuint64m4_t)(op1), (size_t)(op2))
#define vluxei64_v_f64m4_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f64m4_m((vfloat64m4_t)(op0), (const double *)(op1), (vuint64m4_t)(op2), (vbool16_t)(op3), (size_t)(op4))
#define vluxei64_v_f64m8(op0, op1, op2) \
__builtin_rvv_vluxei64_v_f64m8((const double *)(op0), (vuint64m8_t)(op1), (size_t)(op2))
#define vluxei64_v_f64m8_m(op3, op0, op1, op2, op4) \
__builtin_rvv_vluxei64_v_f64m8_m((vfloat64m8_t)(op0), (const double *)(op1), (vuint64m8_t)(op2), (vbool8_t)(op3), (size_t)(op4))
#endif

#define __riscv_v_intrinsic_overloading 1
#define __rvv_overloaded static inline __attribute__((__always_inline__, __nodebug__, __overloadable__))
__rvv_overloaded vint8m1_t vadd(vint8m1_t op0, vint8m1_t op1, size_t op2){
  return vadd_vv_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vadd(vbool8_t op0, vint8m1_t op1, vint8m1_t op2, vint8m1_t op3, size_t op4){
  return vadd_vv_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vadd(vint8m2_t op0, vint8m2_t op1, size_t op2){
  return vadd_vv_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vadd(vbool4_t op0, vint8m2_t op1, vint8m2_t op2, vint8m2_t op3, size_t op4){
  return vadd_vv_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vadd(vint8m4_t op0, vint8m4_t op1, size_t op2){
  return vadd_vv_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vadd(vbool2_t op0, vint8m4_t op1, vint8m4_t op2, vint8m4_t op3, size_t op4){
  return vadd_vv_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m8_t vadd(vint8m8_t op0, vint8m8_t op1, size_t op2){
  return vadd_vv_i8m8(op0, op1, op2);
}

__rvv_overloaded vint8m8_t vadd(vbool1_t op0, vint8m8_t op1, vint8m8_t op2, vint8m8_t op3, size_t op4){
  return vadd_vv_i8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vadd(vint8mf2_t op0, vint8mf2_t op1, size_t op2){
  return vadd_vv_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vadd(vbool16_t op0, vint8mf2_t op1, vint8mf2_t op2, vint8mf2_t op3, size_t op4){
  return vadd_vv_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vadd(vint8mf4_t op0, vint8mf4_t op1, size_t op2){
  return vadd_vv_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vadd(vbool32_t op0, vint8mf4_t op1, vint8mf4_t op2, vint8mf4_t op3, size_t op4){
  return vadd_vv_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vadd(vint8mf8_t op0, vint8mf8_t op1, size_t op2){
  return vadd_vv_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vadd(vbool64_t op0, vint8mf8_t op1, vint8mf8_t op2, vint8mf8_t op3, size_t op4){
  return vadd_vv_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vadd(vint16m1_t op0, vint16m1_t op1, size_t op2){
  return vadd_vv_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vadd(vbool16_t op0, vint16m1_t op1, vint16m1_t op2, vint16m1_t op3, size_t op4){
  return vadd_vv_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vadd(vint16m2_t op0, vint16m2_t op1, size_t op2){
  return vadd_vv_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vadd(vbool8_t op0, vint16m2_t op1, vint16m2_t op2, vint16m2_t op3, size_t op4){
  return vadd_vv_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vadd(vint16m4_t op0, vint16m4_t op1, size_t op2){
  return vadd_vv_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vadd(vbool4_t op0, vint16m4_t op1, vint16m4_t op2, vint16m4_t op3, size_t op4){
  return vadd_vv_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vadd(vint16m8_t op0, vint16m8_t op1, size_t op2){
  return vadd_vv_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vadd(vbool2_t op0, vint16m8_t op1, vint16m8_t op2, vint16m8_t op3, size_t op4){
  return vadd_vv_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vadd(vint16mf2_t op0, vint16mf2_t op1, size_t op2){
  return vadd_vv_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vadd(vbool32_t op0, vint16mf2_t op1, vint16mf2_t op2, vint16mf2_t op3, size_t op4){
  return vadd_vv_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vadd(vint16mf4_t op0, vint16mf4_t op1, size_t op2){
  return vadd_vv_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vadd(vbool64_t op0, vint16mf4_t op1, vint16mf4_t op2, vint16mf4_t op3, size_t op4){
  return vadd_vv_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vadd(vint32m1_t op0, vint32m1_t op1, size_t op2){
  return vadd_vv_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vadd(vbool32_t op0, vint32m1_t op1, vint32m1_t op2, vint32m1_t op3, size_t op4){
  return vadd_vv_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vadd(vint32m2_t op0, vint32m2_t op1, size_t op2){
  return vadd_vv_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vadd(vbool16_t op0, vint32m2_t op1, vint32m2_t op2, vint32m2_t op3, size_t op4){
  return vadd_vv_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vadd(vint32m4_t op0, vint32m4_t op1, size_t op2){
  return vadd_vv_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vadd(vbool8_t op0, vint32m4_t op1, vint32m4_t op2, vint32m4_t op3, size_t op4){
  return vadd_vv_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vadd(vint32m8_t op0, vint32m8_t op1, size_t op2){
  return vadd_vv_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vadd(vbool4_t op0, vint32m8_t op1, vint32m8_t op2, vint32m8_t op3, size_t op4){
  return vadd_vv_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vadd(vint32mf2_t op0, vint32mf2_t op1, size_t op2){
  return vadd_vv_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vadd(vbool64_t op0, vint32mf2_t op1, vint32mf2_t op2, vint32mf2_t op3, size_t op4){
  return vadd_vv_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vadd(vint64m1_t op0, vint64m1_t op1, size_t op2){
  return vadd_vv_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vadd(vbool64_t op0, vint64m1_t op1, vint64m1_t op2, vint64m1_t op3, size_t op4){
  return vadd_vv_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vadd(vint64m2_t op0, vint64m2_t op1, size_t op2){
  return vadd_vv_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vadd(vbool32_t op0, vint64m2_t op1, vint64m2_t op2, vint64m2_t op3, size_t op4){
  return vadd_vv_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vadd(vint64m4_t op0, vint64m4_t op1, size_t op2){
  return vadd_vv_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vadd(vbool16_t op0, vint64m4_t op1, vint64m4_t op2, vint64m4_t op3, size_t op4){
  return vadd_vv_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vadd(vint64m8_t op0, vint64m8_t op1, size_t op2){
  return vadd_vv_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vadd(vbool8_t op0, vint64m8_t op1, vint64m8_t op2, vint64m8_t op3, size_t op4){
  return vadd_vv_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vle8(vbool8_t op0, vint8m1_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8m2_t vle8(vbool4_t op0, vint8m2_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8m4_t vle8(vbool2_t op0, vint8m4_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8m8_t vle8(vbool1_t op0, vint8m8_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8mf2_t vle8(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8mf4_t vle8(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8mf8_t vle8(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, size_t op3){
  return vle8_v_i8mf8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint64m1_t vloxei64(const uint64_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vloxei64(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vloxei64(const uint64_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vloxei64(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vloxei64(const uint64_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vloxei64(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vloxei64(const uint64_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vloxei64(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vadd(vint8m1_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vadd(vbool8_t op0, vint8m1_t op1, vint8m1_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vadd(vint8m2_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vadd(vbool4_t op0, vint8m2_t op1, vint8m2_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vadd(vint8m4_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vadd(vbool2_t op0, vint8m4_t op1, vint8m4_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m8_t vadd(vint8m8_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8m8(op0, op1, op2);
}

__rvv_overloaded vint8m8_t vadd(vbool1_t op0, vint8m8_t op1, vint8m8_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vadd(vint8mf2_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vadd(vbool16_t op0, vint8mf2_t op1, vint8mf2_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vadd(vint8mf4_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vadd(vbool32_t op0, vint8mf4_t op1, vint8mf4_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vadd(vint8mf8_t op0, int8_t op1, size_t op2){
  return vadd_vx_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vadd(vbool64_t op0, vint8mf8_t op1, vint8mf8_t op2, int8_t op3, size_t op4){
  return vadd_vx_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vadd(vint16m1_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vadd(vbool16_t op0, vint16m1_t op1, vint16m1_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vadd(vint16m2_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vadd(vbool8_t op0, vint16m2_t op1, vint16m2_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vadd(vint16m4_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vadd(vbool4_t op0, vint16m4_t op1, vint16m4_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vadd(vint16m8_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vadd(vbool2_t op0, vint16m8_t op1, vint16m8_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vadd(vint16mf2_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vadd(vbool32_t op0, vint16mf2_t op1, vint16mf2_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vadd(vint16mf4_t op0, int16_t op1, size_t op2){
  return vadd_vx_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vadd(vbool64_t op0, vint16mf4_t op1, vint16mf4_t op2, int16_t op3, size_t op4){
  return vadd_vx_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vadd(vint32m1_t op0, int32_t op1, size_t op2){
  return vadd_vx_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vadd(vbool32_t op0, vint32m1_t op1, vint32m1_t op2, int32_t op3, size_t op4){
  return vadd_vx_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vadd(vint32m2_t op0, int32_t op1, size_t op2){
  return vadd_vx_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vadd(vbool16_t op0, vint32m2_t op1, vint32m2_t op2, int32_t op3, size_t op4){
  return vadd_vx_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vadd(vint32m4_t op0, int32_t op1, size_t op2){
  return vadd_vx_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vadd(vbool8_t op0, vint32m4_t op1, vint32m4_t op2, int32_t op3, size_t op4){
  return vadd_vx_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vadd(vint32m8_t op0, int32_t op1, size_t op2){
  return vadd_vx_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vadd(vbool4_t op0, vint32m8_t op1, vint32m8_t op2, int32_t op3, size_t op4){
  return vadd_vx_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vadd(vint32mf2_t op0, int32_t op1, size_t op2){
  return vadd_vx_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vadd(vbool64_t op0, vint32mf2_t op1, vint32mf2_t op2, int32_t op3, size_t op4){
  return vadd_vx_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vadd(vint64m1_t op0, int64_t op1, size_t op2){
  return vadd_vx_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vadd(vbool64_t op0, vint64m1_t op1, vint64m1_t op2, int64_t op3, size_t op4){
  return vadd_vx_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vadd(vint64m2_t op0, int64_t op1, size_t op2){
  return vadd_vx_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vadd(vbool32_t op0, vint64m2_t op1, vint64m2_t op2, int64_t op3, size_t op4){
  return vadd_vx_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vadd(vint64m4_t op0, int64_t op1, size_t op2){
  return vadd_vx_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vadd(vbool16_t op0, vint64m4_t op1, vint64m4_t op2, int64_t op3, size_t op4){
  return vadd_vx_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vadd(vint64m8_t op0, int64_t op1, size_t op2){
  return vadd_vx_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vadd(vbool8_t op0, vint64m8_t op1, vint64m8_t op2, int64_t op3, size_t op4){
  return vadd_vx_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded void vse8(int8_t * op0, vint8m1_t op1, size_t op2){
  return vse8_v_i8m1(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool8_t op0, int8_t * op1, vint8m1_t op2, size_t op3){
  return vse8_v_i8m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8m2_t op1, size_t op2){
  return vse8_v_i8m2(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool4_t op0, int8_t * op1, vint8m2_t op2, size_t op3){
  return vse8_v_i8m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8m4_t op1, size_t op2){
  return vse8_v_i8m4(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool2_t op0, int8_t * op1, vint8m4_t op2, size_t op3){
  return vse8_v_i8m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8m8_t op1, size_t op2){
  return vse8_v_i8m8(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool1_t op0, int8_t * op1, vint8m8_t op2, size_t op3){
  return vse8_v_i8m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8mf2_t op1, size_t op2){
  return vse8_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool16_t op0, int8_t * op1, vint8mf2_t op2, size_t op3){
  return vse8_v_i8mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8mf4_t op1, size_t op2){
  return vse8_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool32_t op0, int8_t * op1, vint8mf4_t op2, size_t op3){
  return vse8_v_i8mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(int8_t * op0, vint8mf8_t op1, size_t op2){
  return vse8_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool64_t op0, int8_t * op1, vint8mf8_t op2, size_t op3){
  return vse8_v_i8mf8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8m1_t vadd(vuint8m1_t op0, vuint8m1_t op1, size_t op2){
  return vadd_vv_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vadd(vbool8_t op0, vuint8m1_t op1, vuint8m1_t op2, vuint8m1_t op3, size_t op4){
  return vadd_vv_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vadd(vuint8m2_t op0, vuint8m2_t op1, size_t op2){
  return vadd_vv_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vadd(vbool4_t op0, vuint8m2_t op1, vuint8m2_t op2, vuint8m2_t op3, size_t op4){
  return vadd_vv_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vadd(vuint8m4_t op0, vuint8m4_t op1, size_t op2){
  return vadd_vv_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vadd(vbool2_t op0, vuint8m4_t op1, vuint8m4_t op2, vuint8m4_t op3, size_t op4){
  return vadd_vv_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m8_t vadd(vuint8m8_t op0, vuint8m8_t op1, size_t op2){
  return vadd_vv_u8m8(op0, op1, op2);
}

__rvv_overloaded vuint8m8_t vadd(vbool1_t op0, vuint8m8_t op1, vuint8m8_t op2, vuint8m8_t op3, size_t op4){
  return vadd_vv_u8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vadd(vuint8mf2_t op0, vuint8mf2_t op1, size_t op2){
  return vadd_vv_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vadd(vbool16_t op0, vuint8mf2_t op1, vuint8mf2_t op2, vuint8mf2_t op3, size_t op4){
  return vadd_vv_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vadd(vuint8mf4_t op0, vuint8mf4_t op1, size_t op2){
  return vadd_vv_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vadd(vbool32_t op0, vuint8mf4_t op1, vuint8mf4_t op2, vuint8mf4_t op3, size_t op4){
  return vadd_vv_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vadd(vuint8mf8_t op0, vuint8mf8_t op1, size_t op2){
  return vadd_vv_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vadd(vbool64_t op0, vuint8mf8_t op1, vuint8mf8_t op2, vuint8mf8_t op3, size_t op4){
  return vadd_vv_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vadd(vuint16m1_t op0, vuint16m1_t op1, size_t op2){
  return vadd_vv_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vadd(vbool16_t op0, vuint16m1_t op1, vuint16m1_t op2, vuint16m1_t op3, size_t op4){
  return vadd_vv_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vadd(vuint16m2_t op0, vuint16m2_t op1, size_t op2){
  return vadd_vv_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vadd(vbool8_t op0, vuint16m2_t op1, vuint16m2_t op2, vuint16m2_t op3, size_t op4){
  return vadd_vv_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vadd(vuint16m4_t op0, vuint16m4_t op1, size_t op2){
  return vadd_vv_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vadd(vbool4_t op0, vuint16m4_t op1, vuint16m4_t op2, vuint16m4_t op3, size_t op4){
  return vadd_vv_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vadd(vuint16m8_t op0, vuint16m8_t op1, size_t op2){
  return vadd_vv_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vadd(vbool2_t op0, vuint16m8_t op1, vuint16m8_t op2, vuint16m8_t op3, size_t op4){
  return vadd_vv_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vadd(vuint16mf2_t op0, vuint16mf2_t op1, size_t op2){
  return vadd_vv_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vadd(vbool32_t op0, vuint16mf2_t op1, vuint16mf2_t op2, vuint16mf2_t op3, size_t op4){
  return vadd_vv_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vadd(vuint16mf4_t op0, vuint16mf4_t op1, size_t op2){
  return vadd_vv_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vadd(vbool64_t op0, vuint16mf4_t op1, vuint16mf4_t op2, vuint16mf4_t op3, size_t op4){
  return vadd_vv_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vadd(vuint32m1_t op0, vuint32m1_t op1, size_t op2){
  return vadd_vv_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vadd(vbool32_t op0, vuint32m1_t op1, vuint32m1_t op2, vuint32m1_t op3, size_t op4){
  return vadd_vv_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vadd(vuint32m2_t op0, vuint32m2_t op1, size_t op2){
  return vadd_vv_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vadd(vbool16_t op0, vuint32m2_t op1, vuint32m2_t op2, vuint32m2_t op3, size_t op4){
  return vadd_vv_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vadd(vuint32m4_t op0, vuint32m4_t op1, size_t op2){
  return vadd_vv_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vadd(vbool8_t op0, vuint32m4_t op1, vuint32m4_t op2, vuint32m4_t op3, size_t op4){
  return vadd_vv_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vadd(vuint32m8_t op0, vuint32m8_t op1, size_t op2){
  return vadd_vv_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vadd(vbool4_t op0, vuint32m8_t op1, vuint32m8_t op2, vuint32m8_t op3, size_t op4){
  return vadd_vv_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vadd(vuint32mf2_t op0, vuint32mf2_t op1, size_t op2){
  return vadd_vv_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vadd(vbool64_t op0, vuint32mf2_t op1, vuint32mf2_t op2, vuint32mf2_t op3, size_t op4){
  return vadd_vv_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vadd(vuint64m1_t op0, vuint64m1_t op1, size_t op2){
  return vadd_vv_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vadd(vbool64_t op0, vuint64m1_t op1, vuint64m1_t op2, vuint64m1_t op3, size_t op4){
  return vadd_vv_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vadd(vuint64m2_t op0, vuint64m2_t op1, size_t op2){
  return vadd_vv_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vadd(vbool32_t op0, vuint64m2_t op1, vuint64m2_t op2, vuint64m2_t op3, size_t op4){
  return vadd_vv_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vadd(vuint64m4_t op0, vuint64m4_t op1, size_t op2){
  return vadd_vv_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vadd(vbool16_t op0, vuint64m4_t op1, vuint64m4_t op2, vuint64m4_t op3, size_t op4){
  return vadd_vv_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vadd(vuint64m8_t op0, vuint64m8_t op1, size_t op2){
  return vadd_vv_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vadd(vbool8_t op0, vuint64m8_t op1, vuint64m8_t op2, vuint64m8_t op3, size_t op4){
  return vadd_vv_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vadd(vuint8m1_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vadd(vbool8_t op0, vuint8m1_t op1, vuint8m1_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vadd(vuint8m2_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vadd(vbool4_t op0, vuint8m2_t op1, vuint8m2_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vadd(vuint8m4_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vadd(vbool2_t op0, vuint8m4_t op1, vuint8m4_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m8_t vadd(vuint8m8_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8m8(op0, op1, op2);
}

__rvv_overloaded vuint8m8_t vadd(vbool1_t op0, vuint8m8_t op1, vuint8m8_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vadd(vuint8mf2_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vadd(vbool16_t op0, vuint8mf2_t op1, vuint8mf2_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vadd(vuint8mf4_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vadd(vbool32_t op0, vuint8mf4_t op1, vuint8mf4_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vadd(vuint8mf8_t op0, uint8_t op1, size_t op2){
  return vadd_vx_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vadd(vbool64_t op0, vuint8mf8_t op1, vuint8mf8_t op2, uint8_t op3, size_t op4){
  return vadd_vx_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vadd(vuint16m1_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vadd(vbool16_t op0, vuint16m1_t op1, vuint16m1_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vadd(vuint16m2_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vadd(vbool8_t op0, vuint16m2_t op1, vuint16m2_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vadd(vuint16m4_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vadd(vbool4_t op0, vuint16m4_t op1, vuint16m4_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vadd(vuint16m8_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vadd(vbool2_t op0, vuint16m8_t op1, vuint16m8_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vadd(vuint16mf2_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vadd(vbool32_t op0, vuint16mf2_t op1, vuint16mf2_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vadd(vuint16mf4_t op0, uint16_t op1, size_t op2){
  return vadd_vx_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vadd(vbool64_t op0, vuint16mf4_t op1, vuint16mf4_t op2, uint16_t op3, size_t op4){
  return vadd_vx_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vadd(vuint32m1_t op0, uint32_t op1, size_t op2){
  return vadd_vx_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vadd(vbool32_t op0, vuint32m1_t op1, vuint32m1_t op2, uint32_t op3, size_t op4){
  return vadd_vx_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vadd(vuint32m2_t op0, uint32_t op1, size_t op2){
  return vadd_vx_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vadd(vbool16_t op0, vuint32m2_t op1, vuint32m2_t op2, uint32_t op3, size_t op4){
  return vadd_vx_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vadd(vuint32m4_t op0, uint32_t op1, size_t op2){
  return vadd_vx_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vadd(vbool8_t op0, vuint32m4_t op1, vuint32m4_t op2, uint32_t op3, size_t op4){
  return vadd_vx_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vadd(vuint32m8_t op0, uint32_t op1, size_t op2){
  return vadd_vx_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vadd(vbool4_t op0, vuint32m8_t op1, vuint32m8_t op2, uint32_t op3, size_t op4){
  return vadd_vx_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vadd(vuint32mf2_t op0, uint32_t op1, size_t op2){
  return vadd_vx_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vadd(vbool64_t op0, vuint32mf2_t op1, vuint32mf2_t op2, uint32_t op3, size_t op4){
  return vadd_vx_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vadd(vuint64m1_t op0, uint64_t op1, size_t op2){
  return vadd_vx_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vadd(vbool64_t op0, vuint64m1_t op1, vuint64m1_t op2, uint64_t op3, size_t op4){
  return vadd_vx_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vadd(vuint64m2_t op0, uint64_t op1, size_t op2){
  return vadd_vx_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vadd(vbool32_t op0, vuint64m2_t op1, vuint64m2_t op2, uint64_t op3, size_t op4){
  return vadd_vx_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vadd(vuint64m4_t op0, uint64_t op1, size_t op2){
  return vadd_vx_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vadd(vbool16_t op0, vuint64m4_t op1, vuint64m4_t op2, uint64_t op3, size_t op4){
  return vadd_vx_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vadd(vuint64m8_t op0, uint64_t op1, size_t op2){
  return vadd_vx_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vadd(vbool8_t op0, vuint64m8_t op1, vuint64m8_t op2, uint64_t op3, size_t op4){
  return vadd_vx_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8m1_t op1, size_t op2){
  return vse8_v_u8m1(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool8_t op0, uint8_t * op1, vuint8m1_t op2, size_t op3){
  return vse8_v_u8m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8m2_t op1, size_t op2){
  return vse8_v_u8m2(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool4_t op0, uint8_t * op1, vuint8m2_t op2, size_t op3){
  return vse8_v_u8m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8m4_t op1, size_t op2){
  return vse8_v_u8m4(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool2_t op0, uint8_t * op1, vuint8m4_t op2, size_t op3){
  return vse8_v_u8m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8m8_t op1, size_t op2){
  return vse8_v_u8m8(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool1_t op0, uint8_t * op1, vuint8m8_t op2, size_t op3){
  return vse8_v_u8m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8mf2_t op1, size_t op2){
  return vse8_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool16_t op0, uint8_t * op1, vuint8mf2_t op2, size_t op3){
  return vse8_v_u8mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8mf4_t op1, size_t op2){
  return vse8_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool32_t op0, uint8_t * op1, vuint8mf4_t op2, size_t op3){
  return vse8_v_u8mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse8(uint8_t * op0, vuint8mf8_t op1, size_t op2){
  return vse8_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded void vse8(vbool64_t op0, uint8_t * op1, vuint8mf8_t op2, size_t op3){
  return vse8_v_u8mf8_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16m1_t vle16(vbool16_t op0, vint16m1_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16m2_t vle16(vbool8_t op0, vint16m2_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16m4_t vle16(vbool4_t op0, vint16m4_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16m8_t vle16(vbool2_t op0, vint16m8_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16mf2_t vle16(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint16mf4_t vle16(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, size_t op3){
  return vle16_v_i16mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16m1_t vle16(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16m2_t vle16(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16m4_t vle16(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16m8_t vle16(vbool2_t op0, vuint16m8_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16mf2_t vle16(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint16mf4_t vle16(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, size_t op3){
  return vle16_v_u16mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint32m1_t vle32(vbool32_t op0, vint32m1_t op1, const int32_t * op2, size_t op3){
  return vle32_v_i32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vint32m2_t vle32(vbool16_t op0, vint32m2_t op1, const int32_t * op2, size_t op3){
  return vle32_v_i32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint32m4_t vle32(vbool8_t op0, vint32m4_t op1, const int32_t * op2, size_t op3){
  return vle32_v_i32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint32m8_t vle32(vbool4_t op0, vint32m8_t op1, const int32_t * op2, size_t op3){
  return vle32_v_i32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vint32mf2_t vle32(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, size_t op3){
  return vle32_v_i32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint32m1_t vle32(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, size_t op3){
  return vle32_v_u32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint32m2_t vle32(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, size_t op3){
  return vle32_v_u32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint32m4_t vle32(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, size_t op3){
  return vle32_v_u32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint32m8_t vle32(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, size_t op3){
  return vle32_v_u32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint32mf2_t vle32(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, size_t op3){
  return vle32_v_u32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint64m1_t vle64(vbool64_t op0, vint64m1_t op1, const int64_t * op2, size_t op3){
  return vle64_v_i64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vint64m2_t vle64(vbool32_t op0, vint64m2_t op1, const int64_t * op2, size_t op3){
  return vle64_v_i64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vint64m4_t vle64(vbool16_t op0, vint64m4_t op1, const int64_t * op2, size_t op3){
  return vle64_v_i64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vint64m8_t vle64(vbool8_t op0, vint64m8_t op1, const int64_t * op2, size_t op3){
  return vle64_v_i64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint64m1_t vle64(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, size_t op3){
  return vle64_v_u64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint64m2_t vle64(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, size_t op3){
  return vle64_v_u64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint64m4_t vle64(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, size_t op3){
  return vle64_v_u64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint64m8_t vle64(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, size_t op3){
  return vle64_v_u64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8m1_t vle8(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8m2_t vle8(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8m4_t vle8(vbool2_t op0, vuint8m4_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8m8_t vle8(vbool1_t op0, vuint8m8_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8mf2_t vle8(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8mf4_t vle8(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded vuint8mf8_t vle8(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, size_t op3){
  return vle8_v_u8mf8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16m1_t op1, size_t op2){
  return vse16_v_i16m1(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool16_t op0, int16_t * op1, vint16m1_t op2, size_t op3){
  return vse16_v_i16m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16m2_t op1, size_t op2){
  return vse16_v_i16m2(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool8_t op0, int16_t * op1, vint16m2_t op2, size_t op3){
  return vse16_v_i16m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16m4_t op1, size_t op2){
  return vse16_v_i16m4(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool4_t op0, int16_t * op1, vint16m4_t op2, size_t op3){
  return vse16_v_i16m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16m8_t op1, size_t op2){
  return vse16_v_i16m8(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool2_t op0, int16_t * op1, vint16m8_t op2, size_t op3){
  return vse16_v_i16m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16mf2_t op1, size_t op2){
  return vse16_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool32_t op0, int16_t * op1, vint16mf2_t op2, size_t op3){
  return vse16_v_i16mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(int16_t * op0, vint16mf4_t op1, size_t op2){
  return vse16_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool64_t op0, int16_t * op1, vint16mf4_t op2, size_t op3){
  return vse16_v_i16mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16m1_t op1, size_t op2){
  return vse16_v_u16m1(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool16_t op0, uint16_t * op1, vuint16m1_t op2, size_t op3){
  return vse16_v_u16m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16m2_t op1, size_t op2){
  return vse16_v_u16m2(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool8_t op0, uint16_t * op1, vuint16m2_t op2, size_t op3){
  return vse16_v_u16m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16m4_t op1, size_t op2){
  return vse16_v_u16m4(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool4_t op0, uint16_t * op1, vuint16m4_t op2, size_t op3){
  return vse16_v_u16m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16m8_t op1, size_t op2){
  return vse16_v_u16m8(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool2_t op0, uint16_t * op1, vuint16m8_t op2, size_t op3){
  return vse16_v_u16m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16mf2_t op1, size_t op2){
  return vse16_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool32_t op0, uint16_t * op1, vuint16mf2_t op2, size_t op3){
  return vse16_v_u16mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse16(uint16_t * op0, vuint16mf4_t op1, size_t op2){
  return vse16_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded void vse16(vbool64_t op0, uint16_t * op1, vuint16mf4_t op2, size_t op3){
  return vse16_v_u16mf4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(int32_t * op0, vint32m1_t op1, size_t op2){
  return vse32_v_i32m1(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool32_t op0, int32_t * op1, vint32m1_t op2, size_t op3){
  return vse32_v_i32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(int32_t * op0, vint32m2_t op1, size_t op2){
  return vse32_v_i32m2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool16_t op0, int32_t * op1, vint32m2_t op2, size_t op3){
  return vse32_v_i32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(int32_t * op0, vint32m4_t op1, size_t op2){
  return vse32_v_i32m4(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool8_t op0, int32_t * op1, vint32m4_t op2, size_t op3){
  return vse32_v_i32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(int32_t * op0, vint32m8_t op1, size_t op2){
  return vse32_v_i32m8(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool4_t op0, int32_t * op1, vint32m8_t op2, size_t op3){
  return vse32_v_i32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(int32_t * op0, vint32mf2_t op1, size_t op2){
  return vse32_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool64_t op0, int32_t * op1, vint32mf2_t op2, size_t op3){
  return vse32_v_i32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(uint32_t * op0, vuint32m1_t op1, size_t op2){
  return vse32_v_u32m1(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool32_t op0, uint32_t * op1, vuint32m1_t op2, size_t op3){
  return vse32_v_u32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(uint32_t * op0, vuint32m2_t op1, size_t op2){
  return vse32_v_u32m2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool16_t op0, uint32_t * op1, vuint32m2_t op2, size_t op3){
  return vse32_v_u32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(uint32_t * op0, vuint32m4_t op1, size_t op2){
  return vse32_v_u32m4(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool8_t op0, uint32_t * op1, vuint32m4_t op2, size_t op3){
  return vse32_v_u32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(uint32_t * op0, vuint32m8_t op1, size_t op2){
  return vse32_v_u32m8(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool4_t op0, uint32_t * op1, vuint32m8_t op2, size_t op3){
  return vse32_v_u32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(uint32_t * op0, vuint32mf2_t op1, size_t op2){
  return vse32_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool64_t op0, uint32_t * op1, vuint32mf2_t op2, size_t op3){
  return vse32_v_u32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(int64_t * op0, vint64m1_t op1, size_t op2){
  return vse64_v_i64m1(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool64_t op0, int64_t * op1, vint64m1_t op2, size_t op3){
  return vse64_v_i64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(int64_t * op0, vint64m2_t op1, size_t op2){
  return vse64_v_i64m2(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool32_t op0, int64_t * op1, vint64m2_t op2, size_t op3){
  return vse64_v_i64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(int64_t * op0, vint64m4_t op1, size_t op2){
  return vse64_v_i64m4(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool16_t op0, int64_t * op1, vint64m4_t op2, size_t op3){
  return vse64_v_i64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(int64_t * op0, vint64m8_t op1, size_t op2){
  return vse64_v_i64m8(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool8_t op0, int64_t * op1, vint64m8_t op2, size_t op3){
  return vse64_v_i64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(uint64_t * op0, vuint64m1_t op1, size_t op2){
  return vse64_v_u64m1(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool64_t op0, uint64_t * op1, vuint64m1_t op2, size_t op3){
  return vse64_v_u64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(uint64_t * op0, vuint64m2_t op1, size_t op2){
  return vse64_v_u64m2(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool32_t op0, uint64_t * op1, vuint64m2_t op2, size_t op3){
  return vse64_v_u64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(uint64_t * op0, vuint64m4_t op1, size_t op2){
  return vse64_v_u64m4(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool16_t op0, uint64_t * op1, vuint64m4_t op2, size_t op3){
  return vse64_v_u64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(uint64_t * op0, vuint64m8_t op1, size_t op2){
  return vse64_v_u64m8(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool8_t op0, uint64_t * op1, vuint64m8_t op2, size_t op3){
  return vse64_v_u64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vint8m1_t vluxei8(const int8_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vluxei8(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vluxei8(const int8_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vluxei8(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vluxei8(const int8_t * op0, vuint8m4_t op1, size_t op2){
  return vluxei8_v_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vluxei8(vbool2_t op0, vint8m4_t op1, const int8_t * op2, vuint8m4_t op3, size_t op4){
  return vluxei8_v_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m8_t vluxei8(const int8_t * op0, vuint8m8_t op1, size_t op2){
  return vluxei8_v_i8m8(op0, op1, op2);
}

__rvv_overloaded vint8m8_t vluxei8(vbool1_t op0, vint8m8_t op1, const int8_t * op2, vuint8m8_t op3, size_t op4){
  return vluxei8_v_i8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vluxei8(const int8_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vluxei8(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vluxei8(const int8_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vluxei8(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vluxei8(const int8_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vluxei8(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vluxei16(const int8_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vluxei16(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vluxei16(const int8_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vluxei16(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vluxei16(const int8_t * op0, vuint16m8_t op1, size_t op2){
  return vluxei16_v_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vluxei16(vbool2_t op0, vint8m4_t op1, const int8_t * op2, vuint16m8_t op3, size_t op4){
  return vluxei16_v_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vluxei16(const int8_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vluxei16(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vluxei16(const int8_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vluxei16(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vluxei16(const int8_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vluxei16(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vluxei16(const uint8_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vluxei16(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vluxei16(const uint8_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vluxei16(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vluxei16(const uint8_t * op0, vuint16m8_t op1, size_t op2){
  return vluxei16_v_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vluxei16(vbool2_t op0, vuint8m4_t op1, const uint8_t * op2, vuint16m8_t op3, size_t op4){
  return vluxei16_v_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vluxei16(const uint8_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vluxei16(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vluxei16(const uint8_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vluxei16(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vluxei16(const uint8_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vluxei16(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vluxei32(const int8_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vluxei32(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vluxei32(const int8_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vluxei32(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vluxei32(const int8_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vluxei32(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vluxei32(const int8_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vluxei32(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vluxei32(const int8_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vluxei32(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vluxei32(const uint8_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vluxei32(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vluxei32(const uint8_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vluxei32(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vluxei32(const uint8_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vluxei32(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vluxei32(const uint8_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vluxei32(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vluxei32(const uint8_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vluxei32(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vluxei64(const int8_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vluxei64(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vluxei64(const int8_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vluxei64(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vluxei64(const int8_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vluxei64(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vluxei64(const int8_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vluxei64(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vluxei64(const uint8_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vluxei64(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vluxei64(const uint8_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vluxei64(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vluxei64(const uint8_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vluxei64(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vluxei64(const uint8_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vluxei64(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vluxei8(const int16_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vluxei8(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vluxei8(const int16_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vluxei8(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vluxei8(const int16_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vluxei8(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vluxei8(const int16_t * op0, vuint8m4_t op1, size_t op2){
  return vluxei8_v_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vluxei8(vbool2_t op0, vint16m8_t op1, const int16_t * op2, vuint8m4_t op3, size_t op4){
  return vluxei8_v_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vluxei8(const int16_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vluxei8(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vluxei8(const int16_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vluxei8(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vluxei8(const uint16_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vluxei8(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vluxei8(const uint16_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vluxei8(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vluxei8(const uint16_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vluxei8(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vluxei8(const uint16_t * op0, vuint8m4_t op1, size_t op2){
  return vluxei8_v_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vluxei8(vbool2_t op0, vuint16m8_t op1, const uint16_t * op2, vuint8m4_t op3, size_t op4){
  return vluxei8_v_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vluxei8(const uint16_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vluxei8(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vluxei8(const uint16_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vluxei8(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vluxei16(const int16_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vluxei16(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vluxei16(const int16_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vluxei16(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vluxei16(const int16_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vluxei16(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vluxei16(const int16_t * op0, vuint16m8_t op1, size_t op2){
  return vluxei16_v_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vluxei16(vbool2_t op0, vint16m8_t op1, const int16_t * op2, vuint16m8_t op3, size_t op4){
  return vluxei16_v_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vluxei16(const int16_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vluxei16(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vluxei16(const int16_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vluxei16(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vluxei16(const uint16_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vluxei16(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vluxei16(const uint16_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vluxei16(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vluxei16(const uint16_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vluxei16(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vluxei16(const uint16_t * op0, vuint16m8_t op1, size_t op2){
  return vluxei16_v_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vluxei16(vbool2_t op0, vuint16m8_t op1, const uint16_t * op2, vuint16m8_t op3, size_t op4){
  return vluxei16_v_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vluxei16(const uint16_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vluxei16(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vluxei16(const uint16_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vluxei16(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vluxei8(const uint8_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vluxei8(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vluxei8(const uint8_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vluxei8(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vluxei8(const uint8_t * op0, vuint8m4_t op1, size_t op2){
  return vluxei8_v_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vluxei8(vbool2_t op0, vuint8m4_t op1, const uint8_t * op2, vuint8m4_t op3, size_t op4){
  return vluxei8_v_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m8_t vluxei8(const uint8_t * op0, vuint8m8_t op1, size_t op2){
  return vluxei8_v_u8m8(op0, op1, op2);
}

__rvv_overloaded vuint8m8_t vluxei8(vbool1_t op0, vuint8m8_t op1, const uint8_t * op2, vuint8m8_t op3, size_t op4){
  return vluxei8_v_u8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vluxei8(const uint8_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vluxei8(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vluxei8(const uint8_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vluxei8(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vluxei8(const uint8_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vluxei8(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vluxei32(const int16_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vluxei32(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vluxei32(const int16_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vluxei32(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vluxei32(const int16_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vluxei32(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vluxei32(const int16_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vluxei32(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vluxei32(const int16_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vluxei32(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vluxei32(const uint16_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vluxei32(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vluxei32(const uint16_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vluxei32(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vluxei32(const uint16_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vluxei32(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vluxei32(const uint16_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vluxei32(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vluxei32(const uint16_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vluxei32(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vluxei64(const int16_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vluxei64(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vluxei64(const int16_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vluxei64(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vluxei64(const int16_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vluxei64(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vluxei64(const int16_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vluxei64(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vluxei64(const uint16_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vluxei64(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vluxei64(const uint16_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vluxei64(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vluxei64(const uint16_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vluxei64(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vluxei64(const uint16_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vluxei64(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vluxei8(const int32_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vluxei8(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vluxei8(const int32_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vluxei8(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vluxei8(const int32_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vluxei8(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vluxei8(const int32_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vluxei8(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vluxei8(const int32_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vluxei8(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vluxei8(const uint32_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vluxei8(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vluxei8(const uint32_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vluxei8(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vluxei8(const uint32_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vluxei8(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vluxei8(const uint32_t * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vluxei8(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vluxei8(const uint32_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vluxei8(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vluxei16(const int32_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vluxei16(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vluxei16(const int32_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vluxei16(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vluxei16(const int32_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vluxei16(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vluxei16(const int32_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vluxei16(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vluxei16(const int32_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vluxei16(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vluxei16(const uint32_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vluxei16(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vluxei16(const uint32_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vluxei16(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vluxei16(const uint32_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vluxei16(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vluxei16(const uint32_t * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vluxei16(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vluxei16(const uint32_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vluxei16(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vluxei32(const int32_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vluxei32(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vluxei32(const int32_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vluxei32(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vluxei32(const int32_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vluxei32(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vluxei32(const int32_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vluxei32(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vluxei32(const int32_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vluxei32(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vluxei32(const uint32_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vluxei32(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vluxei32(const uint32_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vluxei32(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vluxei32(const uint32_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vluxei32(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vluxei32(const uint32_t * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vluxei32(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vluxei32(const uint32_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vluxei32(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vluxei64(const int32_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vluxei64(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vluxei64(const int32_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vluxei64(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vluxei64(const int32_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vluxei64(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vluxei64(const int32_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vluxei64(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vluxei64(const uint32_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vluxei64(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vluxei64(const uint32_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vluxei64(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vluxei64(const uint32_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vluxei64(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vluxei64(const uint32_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vluxei64(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vluxei8(const int64_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vluxei8(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vluxei8(const int64_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vluxei8(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vluxei8(const int64_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vluxei8(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vluxei8(const int64_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vluxei8(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vluxei8(const uint64_t * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vluxei8(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vluxei8(const uint64_t * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vluxei8(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vluxei8(const uint64_t * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vluxei8(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vluxei8(const uint64_t * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vluxei8(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vluxei16(const int64_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vluxei16(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vluxei16(const int64_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vluxei16(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vluxei16(const int64_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vluxei16(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vluxei16(const int64_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vluxei16(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vluxei16(const uint64_t * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vluxei16(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vluxei16(const uint64_t * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vluxei16(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vluxei16(const uint64_t * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vluxei16(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vluxei16(const uint64_t * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vluxei16(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vluxei32(const int64_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vluxei32(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vluxei32(const int64_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vluxei32(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vluxei32(const int64_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vluxei32(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vluxei32(const int64_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vluxei32(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vluxei32(const uint64_t * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vluxei32(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vluxei32(const uint64_t * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vluxei32(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vluxei32(const uint64_t * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vluxei32(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vluxei32(const uint64_t * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vluxei32(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vluxei64(const int64_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vluxei64(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vluxei64(const int64_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vluxei64(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vluxei64(const int64_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vluxei64(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vluxei64(const int64_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vluxei64(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vluxei64(const uint64_t * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vluxei64(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vluxei64(const uint64_t * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vluxei64(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vluxei64(const uint64_t * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vluxei64(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vluxei64(const uint64_t * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vluxei64(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vloxei8(const int8_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vloxei8(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vloxei8(const int8_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vloxei8(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vloxei8(const int8_t * op0, vuint8m4_t op1, size_t op2){
  return vloxei8_v_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vloxei8(vbool2_t op0, vint8m4_t op1, const int8_t * op2, vuint8m4_t op3, size_t op4){
  return vloxei8_v_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m8_t vloxei8(const int8_t * op0, vuint8m8_t op1, size_t op2){
  return vloxei8_v_i8m8(op0, op1, op2);
}

__rvv_overloaded vint8m8_t vloxei8(vbool1_t op0, vint8m8_t op1, const int8_t * op2, vuint8m8_t op3, size_t op4){
  return vloxei8_v_i8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vloxei8(const int8_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vloxei8(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vloxei8(const int8_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vloxei8(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vloxei8(const int8_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vloxei8(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vloxei8(const uint8_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vloxei8(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vloxei8(const uint8_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vloxei8(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vloxei8(const uint8_t * op0, vuint8m4_t op1, size_t op2){
  return vloxei8_v_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vloxei8(vbool2_t op0, vuint8m4_t op1, const uint8_t * op2, vuint8m4_t op3, size_t op4){
  return vloxei8_v_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m8_t vloxei8(const uint8_t * op0, vuint8m8_t op1, size_t op2){
  return vloxei8_v_u8m8(op0, op1, op2);
}

__rvv_overloaded vuint8m8_t vloxei8(vbool1_t op0, vuint8m8_t op1, const uint8_t * op2, vuint8m8_t op3, size_t op4){
  return vloxei8_v_u8m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vloxei8(const uint8_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vloxei8(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vloxei8(const uint8_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vloxei8(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vloxei8(const uint8_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vloxei8(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vloxei16(const int8_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vloxei16(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vloxei16(const int8_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vloxei16(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m4_t vloxei16(const int8_t * op0, vuint16m8_t op1, size_t op2){
  return vloxei16_v_i8m4(op0, op1, op2);
}

__rvv_overloaded vint8m4_t vloxei16(vbool2_t op0, vint8m4_t op1, const int8_t * op2, vuint16m8_t op3, size_t op4){
  return vloxei16_v_i8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vloxei16(const int8_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vloxei16(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vloxei16(const int8_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vloxei16(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vloxei16(const int8_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vloxei16(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vloxei16(const uint8_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vloxei16(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vloxei16(const uint8_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vloxei16(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m4_t vloxei16(const uint8_t * op0, vuint16m8_t op1, size_t op2){
  return vloxei16_v_u8m4(op0, op1, op2);
}

__rvv_overloaded vuint8m4_t vloxei16(vbool2_t op0, vuint8m4_t op1, const uint8_t * op2, vuint16m8_t op3, size_t op4){
  return vloxei16_v_u8m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vloxei16(const uint8_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vloxei16(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vloxei16(const uint8_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vloxei16(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vloxei16(const uint8_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vloxei16(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vloxei32(const int8_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vloxei32(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m2_t vloxei32(const int8_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_i8m2(op0, op1, op2);
}

__rvv_overloaded vint8m2_t vloxei32(vbool4_t op0, vint8m2_t op1, const int8_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_i8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vloxei32(const int8_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vloxei32(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vloxei32(const int8_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vloxei32(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vloxei32(const int8_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vloxei32(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vloxei32(const uint8_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vloxei32(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m2_t vloxei32(const uint8_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_u8m2(op0, op1, op2);
}

__rvv_overloaded vuint8m2_t vloxei32(vbool4_t op0, vuint8m2_t op1, const uint8_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_u8m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vloxei32(const uint8_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vloxei32(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vloxei32(const uint8_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vloxei32(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vloxei32(const uint8_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vloxei32(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8m1_t vloxei64(const int8_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_i8m1(op0, op1, op2);
}

__rvv_overloaded vint8m1_t vloxei64(vbool8_t op0, vint8m1_t op1, const int8_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_i8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf2_t vloxei64(const int8_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_i8mf2(op0, op1, op2);
}

__rvv_overloaded vint8mf2_t vloxei64(vbool16_t op0, vint8mf2_t op1, const int8_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_i8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf4_t vloxei64(const int8_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_i8mf4(op0, op1, op2);
}

__rvv_overloaded vint8mf4_t vloxei64(vbool32_t op0, vint8mf4_t op1, const int8_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_i8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint8mf8_t vloxei64(const int8_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_i8mf8(op0, op1, op2);
}

__rvv_overloaded vint8mf8_t vloxei64(vbool64_t op0, vint8mf8_t op1, const int8_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_i8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8m1_t vloxei64(const uint8_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_u8m1(op0, op1, op2);
}

__rvv_overloaded vuint8m1_t vloxei64(vbool8_t op0, vuint8m1_t op1, const uint8_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_u8m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf2_t vloxei64(const uint8_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_u8mf2(op0, op1, op2);
}

__rvv_overloaded vuint8mf2_t vloxei64(vbool16_t op0, vuint8mf2_t op1, const uint8_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_u8mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf4_t vloxei64(const uint8_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_u8mf4(op0, op1, op2);
}

__rvv_overloaded vuint8mf4_t vloxei64(vbool32_t op0, vuint8mf4_t op1, const uint8_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_u8mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint8mf8_t vloxei64(const uint8_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_u8mf8(op0, op1, op2);
}

__rvv_overloaded vuint8mf8_t vloxei64(vbool64_t op0, vuint8mf8_t op1, const uint8_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_u8mf8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vloxei8(const int16_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vloxei8(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vloxei8(const int16_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vloxei8(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vloxei8(const int16_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vloxei8(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vloxei8(const int16_t * op0, vuint8m4_t op1, size_t op2){
  return vloxei8_v_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vloxei8(vbool2_t op0, vint16m8_t op1, const int16_t * op2, vuint8m4_t op3, size_t op4){
  return vloxei8_v_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vloxei8(const int16_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vloxei8(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vloxei8(const int16_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vloxei8(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vloxei8(const uint16_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vloxei8(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vloxei8(const uint16_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vloxei8(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vloxei8(const uint16_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vloxei8(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vloxei8(const uint16_t * op0, vuint8m4_t op1, size_t op2){
  return vloxei8_v_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vloxei8(vbool2_t op0, vuint16m8_t op1, const uint16_t * op2, vuint8m4_t op3, size_t op4){
  return vloxei8_v_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vloxei8(const uint16_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vloxei8(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vloxei8(const uint16_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vloxei8(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vloxei16(const int16_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vloxei16(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vloxei16(const int16_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vloxei16(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vloxei16(const int16_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vloxei16(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m8_t vloxei16(const int16_t * op0, vuint16m8_t op1, size_t op2){
  return vloxei16_v_i16m8(op0, op1, op2);
}

__rvv_overloaded vint16m8_t vloxei16(vbool2_t op0, vint16m8_t op1, const int16_t * op2, vuint16m8_t op3, size_t op4){
  return vloxei16_v_i16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vloxei16(const int16_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vloxei16(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vloxei16(const int16_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vloxei16(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vloxei16(const uint16_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vloxei16(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vloxei16(const uint16_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vloxei16(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vloxei16(const uint16_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vloxei16(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m8_t vloxei16(const uint16_t * op0, vuint16m8_t op1, size_t op2){
  return vloxei16_v_u16m8(op0, op1, op2);
}

__rvv_overloaded vuint16m8_t vloxei16(vbool2_t op0, vuint16m8_t op1, const uint16_t * op2, vuint16m8_t op3, size_t op4){
  return vloxei16_v_u16m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vloxei16(const uint16_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vloxei16(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vloxei16(const uint16_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vloxei16(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vloxei32(const int16_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vloxei32(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vloxei32(const int16_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vloxei32(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m4_t vloxei32(const int16_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_i16m4(op0, op1, op2);
}

__rvv_overloaded vint16m4_t vloxei32(vbool4_t op0, vint16m4_t op1, const int16_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_i16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vloxei32(const int16_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vloxei32(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vloxei32(const int16_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vloxei32(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vloxei32(const uint16_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vloxei32(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vloxei32(const uint16_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vloxei32(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m4_t vloxei32(const uint16_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_u16m4(op0, op1, op2);
}

__rvv_overloaded vuint16m4_t vloxei32(vbool4_t op0, vuint16m4_t op1, const uint16_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_u16m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vloxei32(const uint16_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vloxei32(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vloxei32(const uint16_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vloxei32(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m1_t vloxei64(const int16_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_i16m1(op0, op1, op2);
}

__rvv_overloaded vint16m1_t vloxei64(vbool16_t op0, vint16m1_t op1, const int16_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_i16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16m2_t vloxei64(const int16_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_i16m2(op0, op1, op2);
}

__rvv_overloaded vint16m2_t vloxei64(vbool8_t op0, vint16m2_t op1, const int16_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_i16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf2_t vloxei64(const int16_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_i16mf2(op0, op1, op2);
}

__rvv_overloaded vint16mf2_t vloxei64(vbool32_t op0, vint16mf2_t op1, const int16_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_i16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint16mf4_t vloxei64(const int16_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_i16mf4(op0, op1, op2);
}

__rvv_overloaded vint16mf4_t vloxei64(vbool64_t op0, vint16mf4_t op1, const int16_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_i16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m1_t vloxei64(const uint16_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_u16m1(op0, op1, op2);
}

__rvv_overloaded vuint16m1_t vloxei64(vbool16_t op0, vuint16m1_t op1, const uint16_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_u16m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16m2_t vloxei64(const uint16_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_u16m2(op0, op1, op2);
}

__rvv_overloaded vuint16m2_t vloxei64(vbool8_t op0, vuint16m2_t op1, const uint16_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_u16m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf2_t vloxei64(const uint16_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_u16mf2(op0, op1, op2);
}

__rvv_overloaded vuint16mf2_t vloxei64(vbool32_t op0, vuint16mf2_t op1, const uint16_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_u16mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint16mf4_t vloxei64(const uint16_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_u16mf4(op0, op1, op2);
}

__rvv_overloaded vuint16mf4_t vloxei64(vbool64_t op0, vuint16mf4_t op1, const uint16_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_u16mf4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vloxei8(const int32_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vloxei8(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vloxei8(const int32_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vloxei8(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vloxei8(const int32_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vloxei8(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vloxei8(const int32_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vloxei8(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vloxei8(const int32_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vloxei8(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vloxei8(const uint32_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vloxei8(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vloxei8(const uint32_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vloxei8(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vloxei8(const uint32_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vloxei8(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vloxei8(const uint32_t * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vloxei8(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vloxei8(const uint32_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vloxei8(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vloxei16(const int32_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vloxei16(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vloxei16(const int32_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vloxei16(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vloxei16(const int32_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vloxei16(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vloxei16(const int32_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vloxei16(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vloxei16(const int32_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vloxei16(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vloxei16(const uint32_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vloxei16(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vloxei16(const uint32_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vloxei16(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vloxei16(const uint32_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vloxei16(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vloxei16(const uint32_t * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vloxei16(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vloxei16(const uint32_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vloxei16(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vloxei32(const int32_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vloxei32(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vloxei32(const int32_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vloxei32(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vloxei32(const int32_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vloxei32(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m8_t vloxei32(const int32_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_i32m8(op0, op1, op2);
}

__rvv_overloaded vint32m8_t vloxei32(vbool4_t op0, vint32m8_t op1, const int32_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_i32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vloxei32(const int32_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vloxei32(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vloxei32(const uint32_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vloxei32(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vloxei32(const uint32_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vloxei32(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vloxei32(const uint32_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vloxei32(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m8_t vloxei32(const uint32_t * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_u32m8(op0, op1, op2);
}

__rvv_overloaded vuint32m8_t vloxei32(vbool4_t op0, vuint32m8_t op1, const uint32_t * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_u32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vloxei32(const uint32_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vloxei32(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m1_t vloxei64(const int32_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_i32m1(op0, op1, op2);
}

__rvv_overloaded vint32m1_t vloxei64(vbool32_t op0, vint32m1_t op1, const int32_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_i32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m2_t vloxei64(const int32_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_i32m2(op0, op1, op2);
}

__rvv_overloaded vint32m2_t vloxei64(vbool16_t op0, vint32m2_t op1, const int32_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_i32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32m4_t vloxei64(const int32_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_i32m4(op0, op1, op2);
}

__rvv_overloaded vint32m4_t vloxei64(vbool8_t op0, vint32m4_t op1, const int32_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_i32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint32mf2_t vloxei64(const int32_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_i32mf2(op0, op1, op2);
}

__rvv_overloaded vint32mf2_t vloxei64(vbool64_t op0, vint32mf2_t op1, const int32_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_i32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m1_t vloxei64(const uint32_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_u32m1(op0, op1, op2);
}

__rvv_overloaded vuint32m1_t vloxei64(vbool32_t op0, vuint32m1_t op1, const uint32_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_u32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m2_t vloxei64(const uint32_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_u32m2(op0, op1, op2);
}

__rvv_overloaded vuint32m2_t vloxei64(vbool16_t op0, vuint32m2_t op1, const uint32_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_u32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32m4_t vloxei64(const uint32_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_u32m4(op0, op1, op2);
}

__rvv_overloaded vuint32m4_t vloxei64(vbool8_t op0, vuint32m4_t op1, const uint32_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_u32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint32mf2_t vloxei64(const uint32_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_u32mf2(op0, op1, op2);
}

__rvv_overloaded vuint32mf2_t vloxei64(vbool64_t op0, vuint32mf2_t op1, const uint32_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_u32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vloxei8(const int64_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vloxei8(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vloxei8(const int64_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vloxei8(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vloxei8(const int64_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vloxei8(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vloxei8(const int64_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vloxei8(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vloxei8(const uint64_t * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vloxei8(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vloxei8(const uint64_t * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vloxei8(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vloxei8(const uint64_t * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vloxei8(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vloxei8(const uint64_t * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vloxei8(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vloxei16(const int64_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vloxei16(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vloxei16(const int64_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vloxei16(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vloxei16(const int64_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vloxei16(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vloxei16(const int64_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vloxei16(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vloxei16(const uint64_t * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vloxei16(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vloxei16(const uint64_t * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vloxei16(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vloxei16(const uint64_t * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vloxei16(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vloxei16(const uint64_t * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vloxei16(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vloxei32(const int64_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vloxei32(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vloxei32(const int64_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vloxei32(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vloxei32(const int64_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vloxei32(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vloxei32(const int64_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vloxei32(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_i64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m1_t vloxei32(const uint64_t * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_u64m1(op0, op1, op2);
}

__rvv_overloaded vuint64m1_t vloxei32(vbool64_t op0, vuint64m1_t op1, const uint64_t * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_u64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m2_t vloxei32(const uint64_t * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_u64m2(op0, op1, op2);
}

__rvv_overloaded vuint64m2_t vloxei32(vbool32_t op0, vuint64m2_t op1, const uint64_t * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_u64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m4_t vloxei32(const uint64_t * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_u64m4(op0, op1, op2);
}

__rvv_overloaded vuint64m4_t vloxei32(vbool16_t op0, vuint64m4_t op1, const uint64_t * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_u64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vuint64m8_t vloxei32(const uint64_t * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_u64m8(op0, op1, op2);
}

__rvv_overloaded vuint64m8_t vloxei32(vbool8_t op0, vuint64m8_t op1, const uint64_t * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_u64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m1_t vloxei64(const int64_t * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_i64m1(op0, op1, op2);
}

__rvv_overloaded vint64m1_t vloxei64(vbool64_t op0, vint64m1_t op1, const int64_t * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_i64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m2_t vloxei64(const int64_t * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_i64m2(op0, op1, op2);
}

__rvv_overloaded vint64m2_t vloxei64(vbool32_t op0, vint64m2_t op1, const int64_t * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_i64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m4_t vloxei64(const int64_t * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_i64m4(op0, op1, op2);
}

__rvv_overloaded vint64m4_t vloxei64(vbool16_t op0, vint64m4_t op1, const int64_t * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_i64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vint64m8_t vloxei64(const int64_t * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_i64m8(op0, op1, op2);
}

__rvv_overloaded vint64m8_t vloxei64(vbool8_t op0, vint64m8_t op1, const int64_t * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_i64m8_m(op0, op1, op2, op3, op4);
}

#if defined(__riscv_f)
__rvv_overloaded vfloat32m1_t vloxei8(const float * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vloxei8(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vloxei8(const float * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vloxei8(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vloxei8(const float * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vloxei8(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vloxei8(const float * op0, vuint8m2_t op1, size_t op2){
  return vloxei8_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vloxei8(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint8m2_t op3, size_t op4){
  return vloxei8_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vloxei8(const float * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vloxei8(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vloxei16(const float * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vloxei16(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vloxei16(const float * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vloxei16(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vloxei16(const float * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vloxei16(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vloxei16(const float * op0, vuint16m4_t op1, size_t op2){
  return vloxei16_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vloxei16(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint16m4_t op3, size_t op4){
  return vloxei16_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vloxei16(const float * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vloxei16(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vloxei32(const float * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vloxei32(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vloxei32(const float * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vloxei32(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vloxei32(const float * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vloxei32(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vloxei32(const float * op0, vuint32m8_t op1, size_t op2){
  return vloxei32_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vloxei32(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint32m8_t op3, size_t op4){
  return vloxei32_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vloxei32(const float * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vloxei32(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vloxei64(const float * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vloxei64(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vloxei64(const float * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vloxei64(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vloxei64(const float * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vloxei64(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vloxei64(const float * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vloxei64(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vfadd(vfloat32m1_t op0, vfloat32m1_t op1, size_t op2){
  return vfadd_vv_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vfadd(vbool32_t op0, vfloat32m1_t op1, vfloat32m1_t op2, vfloat32m1_t op3, size_t op4){
  return vfadd_vv_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vfadd(vfloat32m2_t op0, vfloat32m2_t op1, size_t op2){
  return vfadd_vv_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vfadd(vbool16_t op0, vfloat32m2_t op1, vfloat32m2_t op2, vfloat32m2_t op3, size_t op4){
  return vfadd_vv_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vfadd(vfloat32m4_t op0, vfloat32m4_t op1, size_t op2){
  return vfadd_vv_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vfadd(vbool8_t op0, vfloat32m4_t op1, vfloat32m4_t op2, vfloat32m4_t op3, size_t op4){
  return vfadd_vv_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vfadd(vfloat32m8_t op0, vfloat32m8_t op1, size_t op2){
  return vfadd_vv_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vfadd(vbool4_t op0, vfloat32m8_t op1, vfloat32m8_t op2, vfloat32m8_t op3, size_t op4){
  return vfadd_vv_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vfadd(vfloat32mf2_t op0, vfloat32mf2_t op1, size_t op2){
  return vfadd_vv_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vfadd(vbool64_t op0, vfloat32mf2_t op1, vfloat32mf2_t op2, vfloat32mf2_t op3, size_t op4){
  return vfadd_vv_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vfadd(vfloat32m1_t op0, float op1, size_t op2){
  return vfadd_vf_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vfadd(vbool32_t op0, vfloat32m1_t op1, vfloat32m1_t op2, float op3, size_t op4){
  return vfadd_vf_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vfadd(vfloat32m2_t op0, float op1, size_t op2){
  return vfadd_vf_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vfadd(vbool16_t op0, vfloat32m2_t op1, vfloat32m2_t op2, float op3, size_t op4){
  return vfadd_vf_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vfadd(vfloat32m4_t op0, float op1, size_t op2){
  return vfadd_vf_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vfadd(vbool8_t op0, vfloat32m4_t op1, vfloat32m4_t op2, float op3, size_t op4){
  return vfadd_vf_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vfadd(vfloat32m8_t op0, float op1, size_t op2){
  return vfadd_vf_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vfadd(vbool4_t op0, vfloat32m8_t op1, vfloat32m8_t op2, float op3, size_t op4){
  return vfadd_vf_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vfadd(vfloat32mf2_t op0, float op1, size_t op2){
  return vfadd_vf_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vfadd(vbool64_t op0, vfloat32mf2_t op1, vfloat32mf2_t op2, float op3, size_t op4){
  return vfadd_vf_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vle32(vbool32_t op0, vfloat32m1_t op1, const float * op2, size_t op3){
  return vle32_v_f32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat32m2_t vle32(vbool16_t op0, vfloat32m2_t op1, const float * op2, size_t op3){
  return vle32_v_f32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat32m4_t vle32(vbool8_t op0, vfloat32m4_t op1, const float * op2, size_t op3){
  return vle32_v_f32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat32m8_t vle32(vbool4_t op0, vfloat32m8_t op1, const float * op2, size_t op3){
  return vle32_v_f32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat32mf2_t vle32(vbool64_t op0, vfloat32mf2_t op1, const float * op2, size_t op3){
  return vle32_v_f32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(float * op0, vfloat32m1_t op1, size_t op2){
  return vse32_v_f32m1(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool32_t op0, float * op1, vfloat32m1_t op2, size_t op3){
  return vse32_v_f32m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(float * op0, vfloat32m2_t op1, size_t op2){
  return vse32_v_f32m2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool16_t op0, float * op1, vfloat32m2_t op2, size_t op3){
  return vse32_v_f32m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(float * op0, vfloat32m4_t op1, size_t op2){
  return vse32_v_f32m4(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool8_t op0, float * op1, vfloat32m4_t op2, size_t op3){
  return vse32_v_f32m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(float * op0, vfloat32m8_t op1, size_t op2){
  return vse32_v_f32m8(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool4_t op0, float * op1, vfloat32m8_t op2, size_t op3){
  return vse32_v_f32m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse32(float * op0, vfloat32mf2_t op1, size_t op2){
  return vse32_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded void vse32(vbool64_t op0, float * op1, vfloat32mf2_t op2, size_t op3){
  return vse32_v_f32mf2_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat32m1_t vluxei8(const float * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vluxei8(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vluxei8(const float * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vluxei8(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vluxei8(const float * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vluxei8(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vluxei8(const float * op0, vuint8m2_t op1, size_t op2){
  return vluxei8_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vluxei8(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint8m2_t op3, size_t op4){
  return vluxei8_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vluxei8(const float * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vluxei8(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vluxei16(const float * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vluxei16(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vluxei16(const float * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vluxei16(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vluxei16(const float * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vluxei16(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vluxei16(const float * op0, vuint16m4_t op1, size_t op2){
  return vluxei16_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vluxei16(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint16m4_t op3, size_t op4){
  return vluxei16_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vluxei16(const float * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vluxei16(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vluxei32(const float * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vluxei32(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vluxei32(const float * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vluxei32(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vluxei32(const float * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vluxei32(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m8_t vluxei32(const float * op0, vuint32m8_t op1, size_t op2){
  return vluxei32_v_f32m8(op0, op1, op2);
}

__rvv_overloaded vfloat32m8_t vluxei32(vbool4_t op0, vfloat32m8_t op1, const float * op2, vuint32m8_t op3, size_t op4){
  return vluxei32_v_f32m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vluxei32(const float * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vluxei32(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_f32mf2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m1_t vluxei64(const float * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_f32m1(op0, op1, op2);
}

__rvv_overloaded vfloat32m1_t vluxei64(vbool32_t op0, vfloat32m1_t op1, const float * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_f32m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m2_t vluxei64(const float * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_f32m2(op0, op1, op2);
}

__rvv_overloaded vfloat32m2_t vluxei64(vbool16_t op0, vfloat32m2_t op1, const float * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_f32m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32m4_t vluxei64(const float * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_f32m4(op0, op1, op2);
}

__rvv_overloaded vfloat32m4_t vluxei64(vbool8_t op0, vfloat32m4_t op1, const float * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_f32m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat32mf2_t vluxei64(const float * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_f32mf2(op0, op1, op2);
}

__rvv_overloaded vfloat32mf2_t vluxei64(vbool64_t op0, vfloat32mf2_t op1, const float * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_f32mf2_m(op0, op1, op2, op3, op4);
}

#endif

#if defined(__riscv_d)
__rvv_overloaded vfloat64m1_t vloxei8(const double * op0, vuint8mf8_t op1, size_t op2){
  return vloxei8_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vloxei8(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint8mf8_t op3, size_t op4){
  return vloxei8_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vloxei8(const double * op0, vuint8mf4_t op1, size_t op2){
  return vloxei8_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vloxei8(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint8mf4_t op3, size_t op4){
  return vloxei8_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vloxei8(const double * op0, vuint8mf2_t op1, size_t op2){
  return vloxei8_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vloxei8(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint8mf2_t op3, size_t op4){
  return vloxei8_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vloxei8(const double * op0, vuint8m1_t op1, size_t op2){
  return vloxei8_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vloxei8(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint8m1_t op3, size_t op4){
  return vloxei8_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vloxei16(const double * op0, vuint16mf4_t op1, size_t op2){
  return vloxei16_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vloxei16(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint16mf4_t op3, size_t op4){
  return vloxei16_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vloxei16(const double * op0, vuint16mf2_t op1, size_t op2){
  return vloxei16_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vloxei16(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint16mf2_t op3, size_t op4){
  return vloxei16_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vloxei16(const double * op0, vuint16m1_t op1, size_t op2){
  return vloxei16_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vloxei16(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint16m1_t op3, size_t op4){
  return vloxei16_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vloxei16(const double * op0, vuint16m2_t op1, size_t op2){
  return vloxei16_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vloxei16(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint16m2_t op3, size_t op4){
  return vloxei16_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vloxei32(const double * op0, vuint32mf2_t op1, size_t op2){
  return vloxei32_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vloxei32(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint32mf2_t op3, size_t op4){
  return vloxei32_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vloxei32(const double * op0, vuint32m1_t op1, size_t op2){
  return vloxei32_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vloxei32(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint32m1_t op3, size_t op4){
  return vloxei32_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vloxei32(const double * op0, vuint32m2_t op1, size_t op2){
  return vloxei32_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vloxei32(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint32m2_t op3, size_t op4){
  return vloxei32_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vloxei32(const double * op0, vuint32m4_t op1, size_t op2){
  return vloxei32_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vloxei32(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint32m4_t op3, size_t op4){
  return vloxei32_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vloxei64(const double * op0, vuint64m1_t op1, size_t op2){
  return vloxei64_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vloxei64(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint64m1_t op3, size_t op4){
  return vloxei64_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vloxei64(const double * op0, vuint64m2_t op1, size_t op2){
  return vloxei64_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vloxei64(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint64m2_t op3, size_t op4){
  return vloxei64_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vloxei64(const double * op0, vuint64m4_t op1, size_t op2){
  return vloxei64_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vloxei64(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint64m4_t op3, size_t op4){
  return vloxei64_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vloxei64(const double * op0, vuint64m8_t op1, size_t op2){
  return vloxei64_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vloxei64(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint64m8_t op3, size_t op4){
  return vloxei64_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vfadd(vfloat64m1_t op0, vfloat64m1_t op1, size_t op2){
  return vfadd_vv_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vfadd(vbool64_t op0, vfloat64m1_t op1, vfloat64m1_t op2, vfloat64m1_t op3, size_t op4){
  return vfadd_vv_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vfadd(vfloat64m2_t op0, vfloat64m2_t op1, size_t op2){
  return vfadd_vv_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vfadd(vbool32_t op0, vfloat64m2_t op1, vfloat64m2_t op2, vfloat64m2_t op3, size_t op4){
  return vfadd_vv_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vfadd(vfloat64m4_t op0, vfloat64m4_t op1, size_t op2){
  return vfadd_vv_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vfadd(vbool16_t op0, vfloat64m4_t op1, vfloat64m4_t op2, vfloat64m4_t op3, size_t op4){
  return vfadd_vv_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vfadd(vfloat64m8_t op0, vfloat64m8_t op1, size_t op2){
  return vfadd_vv_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vfadd(vbool8_t op0, vfloat64m8_t op1, vfloat64m8_t op2, vfloat64m8_t op3, size_t op4){
  return vfadd_vv_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vfadd(vfloat64m1_t op0, double op1, size_t op2){
  return vfadd_vf_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vfadd(vbool64_t op0, vfloat64m1_t op1, vfloat64m1_t op2, double op3, size_t op4){
  return vfadd_vf_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vfadd(vfloat64m2_t op0, double op1, size_t op2){
  return vfadd_vf_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vfadd(vbool32_t op0, vfloat64m2_t op1, vfloat64m2_t op2, double op3, size_t op4){
  return vfadd_vf_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vfadd(vfloat64m4_t op0, double op1, size_t op2){
  return vfadd_vf_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vfadd(vbool16_t op0, vfloat64m4_t op1, vfloat64m4_t op2, double op3, size_t op4){
  return vfadd_vf_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vfadd(vfloat64m8_t op0, double op1, size_t op2){
  return vfadd_vf_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vfadd(vbool8_t op0, vfloat64m8_t op1, vfloat64m8_t op2, double op3, size_t op4){
  return vfadd_vf_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vle64(vbool64_t op0, vfloat64m1_t op1, const double * op2, size_t op3){
  return vle64_v_f64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat64m2_t vle64(vbool32_t op0, vfloat64m2_t op1, const double * op2, size_t op3){
  return vle64_v_f64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat64m4_t vle64(vbool16_t op0, vfloat64m4_t op1, const double * op2, size_t op3){
  return vle64_v_f64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat64m8_t vle64(vbool8_t op0, vfloat64m8_t op1, const double * op2, size_t op3){
  return vle64_v_f64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(double * op0, vfloat64m1_t op1, size_t op2){
  return vse64_v_f64m1(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool64_t op0, double * op1, vfloat64m1_t op2, size_t op3){
  return vse64_v_f64m1_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(double * op0, vfloat64m2_t op1, size_t op2){
  return vse64_v_f64m2(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool32_t op0, double * op1, vfloat64m2_t op2, size_t op3){
  return vse64_v_f64m2_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(double * op0, vfloat64m4_t op1, size_t op2){
  return vse64_v_f64m4(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool16_t op0, double * op1, vfloat64m4_t op2, size_t op3){
  return vse64_v_f64m4_m(op0, op1, op2, op3);
}

__rvv_overloaded void vse64(double * op0, vfloat64m8_t op1, size_t op2){
  return vse64_v_f64m8(op0, op1, op2);
}

__rvv_overloaded void vse64(vbool8_t op0, double * op1, vfloat64m8_t op2, size_t op3){
  return vse64_v_f64m8_m(op0, op1, op2, op3);
}

__rvv_overloaded vfloat64m1_t vluxei8(const double * op0, vuint8mf8_t op1, size_t op2){
  return vluxei8_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vluxei8(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint8mf8_t op3, size_t op4){
  return vluxei8_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vluxei8(const double * op0, vuint8mf4_t op1, size_t op2){
  return vluxei8_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vluxei8(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint8mf4_t op3, size_t op4){
  return vluxei8_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vluxei8(const double * op0, vuint8mf2_t op1, size_t op2){
  return vluxei8_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vluxei8(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint8mf2_t op3, size_t op4){
  return vluxei8_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vluxei8(const double * op0, vuint8m1_t op1, size_t op2){
  return vluxei8_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vluxei8(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint8m1_t op3, size_t op4){
  return vluxei8_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vluxei16(const double * op0, vuint16mf4_t op1, size_t op2){
  return vluxei16_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vluxei16(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint16mf4_t op3, size_t op4){
  return vluxei16_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vluxei16(const double * op0, vuint16mf2_t op1, size_t op2){
  return vluxei16_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vluxei16(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint16mf2_t op3, size_t op4){
  return vluxei16_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vluxei16(const double * op0, vuint16m1_t op1, size_t op2){
  return vluxei16_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vluxei16(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint16m1_t op3, size_t op4){
  return vluxei16_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vluxei16(const double * op0, vuint16m2_t op1, size_t op2){
  return vluxei16_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vluxei16(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint16m2_t op3, size_t op4){
  return vluxei16_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vluxei32(const double * op0, vuint32mf2_t op1, size_t op2){
  return vluxei32_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vluxei32(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint32mf2_t op3, size_t op4){
  return vluxei32_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vluxei32(const double * op0, vuint32m1_t op1, size_t op2){
  return vluxei32_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vluxei32(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint32m1_t op3, size_t op4){
  return vluxei32_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vluxei32(const double * op0, vuint32m2_t op1, size_t op2){
  return vluxei32_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vluxei32(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint32m2_t op3, size_t op4){
  return vluxei32_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vluxei32(const double * op0, vuint32m4_t op1, size_t op2){
  return vluxei32_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vluxei32(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint32m4_t op3, size_t op4){
  return vluxei32_v_f64m8_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m1_t vluxei64(const double * op0, vuint64m1_t op1, size_t op2){
  return vluxei64_v_f64m1(op0, op1, op2);
}

__rvv_overloaded vfloat64m1_t vluxei64(vbool64_t op0, vfloat64m1_t op1, const double * op2, vuint64m1_t op3, size_t op4){
  return vluxei64_v_f64m1_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m2_t vluxei64(const double * op0, vuint64m2_t op1, size_t op2){
  return vluxei64_v_f64m2(op0, op1, op2);
}

__rvv_overloaded vfloat64m2_t vluxei64(vbool32_t op0, vfloat64m2_t op1, const double * op2, vuint64m2_t op3, size_t op4){
  return vluxei64_v_f64m2_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m4_t vluxei64(const double * op0, vuint64m4_t op1, size_t op2){
  return vluxei64_v_f64m4(op0, op1, op2);
}

__rvv_overloaded vfloat64m4_t vluxei64(vbool16_t op0, vfloat64m4_t op1, const double * op2, vuint64m4_t op3, size_t op4){
  return vluxei64_v_f64m4_m(op0, op1, op2, op3, op4);
}

__rvv_overloaded vfloat64m8_t vluxei64(const double * op0, vuint64m8_t op1, size_t op2){
  return vluxei64_v_f64m8(op0, op1, op2);
}

__rvv_overloaded vfloat64m8_t vluxei64(vbool8_t op0, vfloat64m8_t op1, const double * op2, vuint64m8_t op3, size_t op4){
  return vluxei64_v_f64m8_m(op0, op1, op2, op3, op4);
}

#endif


#ifdef __cplusplus
}
#endif // __riscv_vector
#endif // __RISCV_VECTOR_H
